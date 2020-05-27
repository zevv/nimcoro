import coro
import nativesockets
import eventqueue

var evq: Evq

type
  Client = ref object
    fd: int
    coro: Coro


# Magic glue between coroutine and event queue

proc magicRead(coro: Coro, fd: int): string =

  # Register a proc on fd-readable event that resumes this coroutine
  evq.addFd(fd, POLLIN, proc() = coro.resume())

  # Jield away, this will return only when the above lambda is called from the evq
  jield()
  evq.delFd(fd)

  # We get here when the socket is readable: recv data and return
  var buf = newString(100)
  let r = recv(fd.SocketHandle, buf[0].addr, buf.len, 0)
  buf.setlen(r)
  return buf


# Coroutine handling one client

proc doClient(coro: Coro, fd: int) =
  while true:
    let buf = magicRead(coro, fd)
    echo "rx> ", buf


# Below is a simple TCP server accepting multiple clients, all in
# the usual callback structure, built on a very simple event loop

proc doServer() =

  # Create TCP server socket

  let fds = createNativeSocket()
  var sa: Sockaddr_in
  sa.sin_family = AF_INET.uint16
  sa.sin_port = htons(9000)
  sa.sin_addr.s_addr = INADDR_ANY
  discard fds.bindAddr(cast[ptr SockAddr](sa.addr), sizeof(sa).SockLen)
  discard fds.listen(SOMAXCONN)

  # Register callback for new client

  evq.addFd(fds.int, POLLIN, proc() =
    let (fdc, st) = fds.accept()
    echo "Accepted new client ", st, ", creating coroutine"
    let co = newCoro("client", doClient, fdc.int)
  )



doServer()

evq.run()

