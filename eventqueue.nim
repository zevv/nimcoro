
# eenie teenie event loop

import posix, tables

export POLLIN, POLLOUT

type

  FdCallback = proc()

  FdHandler = object
    events: int
    fn: proc()

  Evq* = object
    fdhs: Table[int, FdHandler]


# Register/unregister a file descriptor to the loop

proc addFd*(evq: var Evq, fd: int, events: int, fn: FdCallback) =
  evq.fdhs[fd] = FdHandler(events: events, fn: fn)

proc delFd*(evq: var Evq, fd: int) =
  evq.fdhs.del(fd)


# Run one iteration

proc poll(evq: Evq) =

  if evq.fdhs.len == 0:
    echo "Nothing in evq"
    quit 1

  var pfds: seq[TPollfd]

  for fd, fdh in evq.fdhs:
    pfds.add TPollfd(fd: fd.cint, events: fdh.events.cshort)

  let r = posix.poll(pfds[0].addr, pfds.len.Tnfds, -1)

  if r == 0:
    return

  for pfd in pfds:
    if pfd.revents == POLLIN:
      let fdh = evq.fdhs[pfd.fd]
      fdh.fn()


# Run forever

proc run*(evq: Evq) =
  while true:
    evq.poll()


