import coro
import nativesockets
import eventqueue

var evq: Evq

type
  Client = ref object
    fd: int
    coro: Coro

# This is where the magic happens: This will add a function callback to the
# event queue that will resume the current coro, and the coro will yield itself
# to sleep. It will be awoken when the fd has an event,

proc waitForEvent(coro: Coro, fd: int, event: int) =
  evq.addFd(fd, event, proc() = coro.resume())
  jield()
  evq.delFd(fd)

# "async" wait for fd and read data

proc magicRead(coro: Coro, fd: int): string =
  waitForEvent(coro, fd, POLLIN)
  var buf = newString(100)
  let r = recv(fd.SocketHandle, buf[0].addr, buf.len, 0)
  buf.setlen(r)
  return buf

# "async" wait for fd and write data

proc magicWrite(coro: Coro, fd: int, buf: string) =
  waitForEvent(coro, fd, POLLOUT)
  discard send(fd.SocketHandle, buf[0].unsafeAddr, buf.len, 0)

# Coroutine handling one client connection.

proc doClient(coro: Coro, fd: int) =
  magicWrite(coro, fd, "Hello! Please type something.\n")
  while true:
    let buf = magicRead(coro, fd)
    magicWrite(coro, fd, "You sent " & $buf.len & " characters\n")

# Coroutine handling the server socket

proc doServer(coro: Coro, fd: int) =
  while true:
    waitForEvent(coro, fd, POLLIN)
    let (fdc, st) = fd.SocketHandle.accept()
    echo "Accepted new client ", st, ", creating coroutine"
    discard newCoro("client", doClient, fdc.int)

# Create TCP server socket and coroutine

let fds = createNativeSocket()
var sa: Sockaddr_in
sa.sin_family = AF_INET.uint16
sa.sin_port = htons(9000)
sa.sin_addr.s_addr = INADDR_ANY
discard fds.bindAddr(cast[ptr SockAddr](sa.addr), sizeof(sa).SockLen)
discard fds.listen(SOMAXCONN)

discard newCoro("server", doServer, fds.int)

# Forever run the event loop

evq.run()

