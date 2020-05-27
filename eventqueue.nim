
import posix, tables


type

  FdCallback = proc()

  FdHandler = object
    fn: proc()

  Evq* = object
    fdhs: Table[int, FdHandler]


proc addFd*(evq: var Evq, fd: int, fn: FdCallback) =
  evq.fdhs[fd] = FdHandler(fn: fn)


proc poll(evq: Evq) =

  if evq.fdhs.len == 0:
    echo "Nothing in evq"
    quit 1

  var pfds: seq[TPollfd]

  for fd, fdh in evq.fdhs:
    pfds.add TPollfd(fd: fd.cint, events: POLLIN)

  let r = posix.poll(pfds[0].addr, pfds.len.Tnfds, -1)

  if r == 0:
    return

  for pfd in pfds:
    if pfd.revents == POLLIN:
      let fdh = evq.fdhs[pfd.fd]
      fdh.fn()

proc run*(evq: Evq) =
  while true:
    evq.poll()


