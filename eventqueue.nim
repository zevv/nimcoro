
# Basic poll based event loop

import posix, tables

export POLLIN, POLLOUT, POLLERR

type

  Callback = proc(): bool

  HandlerId = int

  FdHandler = ref object
    id: HandlerId
    fd: int
    events: int
    fn: Callback
    deleted: bool

  TimerHandler* = ref object
    id: HandlerId
    interval: float
    tWhen: float
    fn: Callback
    deleted: bool

  Evq* = object
    now: float
    fdHandlers: Table[HandlerId, FdHandler]
    timerHandlers: Table[HandlerId, TimerHandler]
    nextHandlerId: HandlerId

proc now(): float =
  var ts: Timespec
  discard clock_gettime(CLOCK_MONOTONIC, ts)
  return ts.tv_sec.float + ts.tv_nsec.float * 1.0e-9

proc nextId(evq: var Evq): HandlerId =
  inc evq.nextHandlerId
  return evq.nextHandlerId

# Register/unregister a file descriptor to the loop

proc addFd*(evq: var Evq, fd: int, events: int, fn: Callback): HandlerId =
  let id = evq.nextId()
  evq.fdHandlers[id] = FdHandler(id: id, fd: fd, events: events, fn: fn)
  return id

proc delFd*(evq: var Evq, id: HandlerId) =
  evq.fdHandlers[id].deleted = true
  evq.fdHandlers.del id

# Register/unregister timers

proc addTimer*(evq: var Evq, interval: float, fn: Callback): HandlerId =
  let id = evq.nextId()
  evq.timerHandlers[id] = TimerHandler(id: id, tWhen: now()+interval, interval: interval, fn: fn)
  return id

proc delTimer*(evq: var Evq, id: HandlerId) =
  evq.timerHandlers[id].deleted = true
  evq.timerHandlers.del id

# Run one iteration

proc poll(evq: var Evq) =

  if evq.fdHandlers.len == 0:
    echo "Nothing in evq"
    quit 1

  # Calculate sleep time
  
  evq.now = now()
  var tSleep = 100.0
  for id, th in evq.timerHandlers:
    if not th.deleted:
      let dt = th.tWhen - evq.now
      tSleep = min(tSleep, dt)

  # Collect file descriptors for poll set

  var pfds: seq[TPollfd]
  for id, fdh in evq.fdHandlers:
    if not fdh.deleted:
      pfds.add TPollfd(fd: fdh.fd.cint, events: fdh.events.cshort)

  let r = posix.poll(pfds[0].addr, pfds.len.Tnfds, int(tSleep * 1000.0))

  # Call expired timer handlers
  
  evq.now = now()
  var ths: seq[TimerHandler]

  for id, th in evq.timerHandlers:
    if not th.deleted:
      if evq.now > th.tWhen:
        ths.add th

  for th in ths:
    let del = th.fn()
    if not del:
      th.tWhen += th.interval
    else:
      evq.delTimer(th.id)

  # Call fd handlers with events

  if r == 0:
    return

  var fdhs: seq[FdHandler]

  for pfd in pfds:
    if pfd.revents != 0:
      for id, fdh in evq.fdHandlers:
        if not fdh.deleted and fdh.fd == pfd.fd and pfd.revents == fdh.events:
          fdhs.add fdh

  for fdh in fdhs:
    if not fdh.deleted:
      let del = fdh.fn()
      if del:
        evq.delFd(fdh.id)


# Run forever

proc run*(evq: var Evq) =
  while true:
    evq.poll()


