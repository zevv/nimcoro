import coro
import nativesockets
import eventqueue

var evq: Evq

# This is where the magic happens: This will add a function callback to the
# event queue that will resume the current coro, and the coro will yield itself
# to sleep. It will be awoken when the fd has an event,

proc waitForEvent(fd: int, event: int) =
  evq.addFd(fd, event, resumer())
  jield()
  evq.delFd(fd)

# "async" wait for fd and read data

proc asyncRead(fd: int): string =
  waitForEvent(fd, POLLIN)
  var buf = newString(100)
  let r = recv(fd.SocketHandle, buf[0].addr, buf.len, 0)
  buf.setlen(r)
  return buf

# "async" wait for fd and write data

proc asyncWrite(fd: int, buf: string) =
  waitForEvent(fd, POLLOUT)
  discard send(fd.SocketHandle, buf[0].unsafeAddr, buf.len, 0)

# Coroutine handling one client connection.

proc doClient(fd: int) =
  asyncWrite(fd, "Hello! Please type something.\n")
  while true:
    let buf = asyncRead(fd)
    if buf.len > 0:
      asyncWrite(fd, "You sent " & $buf.len & " characters\n")
    else:
      echo "Client went away"
      break

# Coroutine handling the server socket

proc doServer(fd: int) =
  while true:
    waitForEvent(fd, POLLIN)
    let (fdc, st) = fd.SocketHandle.accept()
    echo "Accepted new client ", st, ", creating coroutine"
    discard newCoro(proc() =
      doClient(fdc.int))

# Create TCP server socket and coroutine

let fds = createNativeSocket()
var sa: Sockaddr_in
sa.sin_family = AF_INET.uint16
sa.sin_port = htons(9000)
sa.sin_addr.s_addr = INADDR_ANY
discard fds.bindAddr(cast[ptr SockAddr](sa.addr), sizeof(sa).SockLen)
discard fds.listen(SOMAXCONN)

discard newCoro(proc() =
  doServer(int fds))

# Forever run the event loop

evq.run()

