
# eenie teenie event loop, with bugs

import posix, tables

export POLLIN, POLLOUT

type

  Callback = proc(): bool

  FdHandler = ref object
    events: int
    fn: Callback

  TimerHandler* = ref object
    interval: float
    tWhen: float
    fn: Callback
    delete: bool

  Evq* = object
    now: float
    fdhs: Table[int, FdHandler]
    ths: seq[TimerHandler]

proc now(): float =
  var ts: Timespec
  discard clock_gettime(CLOCK_MONOTONIC, ts)
  return ts.tv_sec.float + ts.tv_nsec.float * 1.0e-9

# Register/unregister a file descriptor to the loop

proc addFd*(evq: var Evq, fd: int, events: int, fn: Callback) =
  evq.fdhs[fd] = FdHandler(events: events, fn: fn)

proc delFd*(evq: var Evq, fd: int) =
  # Wrong, might run from poll() and mess up the iteration
  evq.fdhs.del(fd)

# Register/unregister timers

proc addTimer*(evq: var Evq, interval: float, fn: Callback): TimerHandler {.discardable.} =
  result = TimerHandler(tWhen: now()+interval, interval: interval, fn: fn)
  evq.ths.add(result)


# Run one iteration

proc poll(evq: var Evq) =

  if evq.fdhs.len == 0:
    echo "Nothing in evq"
    quit 1

  evq.now = now()
  var tSleep = 1.0

  # Handle timers

  for th in evq.ths:
    if not th.delete:
      let dt = th.tWhen - evq.now
      if dt <= 0:
        let stop = th.fn()
        if not stop:
          th.tWhen += th.interval
        else:
          th.delete = true
      else:
        tSleep = min(tSleep, dt)

  # Handle file descriptors

  var pfds: seq[TPollfd]
  for fd, fdh in evq.fdhs:
    pfds.add TPollfd(fd: fd.cint, events: fdh.events.cshort)

  let r = posix.poll(pfds[0].addr, pfds.len.Tnfds, int(tSleep * 1000.0))

  if r == 0:
    return

  for pfd in pfds:
    if pfd.revents == pfd.events:
      let fdh = evq.fdhs[pfd.fd]
      discard fdh.fn()


# Run forever

proc run*(evq: var Evq) =
  while true:
    evq.poll()


