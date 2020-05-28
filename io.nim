
import posix
import coro
import eventqueue

# This is where the magic happens: This will add a function callback to the
# event queue that will resume the current coro, and the coro will yield itself
# to sleep. It will be awoken when the fd has an event,

proc waitForFd*(fd: SocketHandle, event: int) =
  let co = coro.running()
  proc resume_me(): bool =
    co.resume()
  let fdh = addFd(fd.int, event, resume_me)
  jield()
  delFd(fdh)


# "async" wait for fd and read data

proc ioRead*(fd: SocketHandle): string =
  waitForFd(fd, POLLIN)
  var buf = newString(100)
  let r = recv(fd, buf[0].addr, buf.len, 0)
  buf.setlen(r)
  return buf

# "async" wait for fd and write data

proc ioWrite*(fd: SocketHandle, buf: string) =
  waitForFd(fd, POLLOUT)
  discard send(fd, buf[0].unsafeAddr, buf.len, 0)


