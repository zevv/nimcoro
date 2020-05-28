import coro
import posix
import eventqueue

let port = 9000
var evq: Evq

type
  MyTask* = ref object of TaskBase
    fd: SocketHandle

# This is where the magic happens: This will add a function callback to the
# event queue that will resume the current coro, and the coro will yield itself
# to sleep. It will be awoken when the fd has an event,

proc waitForEvent(fd: SocketHandle, event: int) =
  let co = coro.running()
  proc resume_me() =
    co.resume()
  evq.addFd(fd.int, event, resume_me)
  jield()
  evq.delFd(fd.int)

# "async" wait for fd and read data

proc asyncRead(fd: SocketHandle): string =
  waitForEvent(fd, POLLIN)
  var buf = newString(100)
  let r = recv(fd, buf[0].addr, buf.len, 0)
  buf.setlen(r)
  return buf

# "async" wait for fd and write data

proc asyncWrite(fd: SocketHandle, buf: string) =
  waitForEvent(fd, POLLOUT)
  discard send(fd, buf[0].unsafeAddr, buf.len, 0)

# Coroutine handling one client connection.

proc doClient(task: TaskBase) =
  let fd = task.Mytask.fd
  asyncWrite(fd, "Hello! Please type something.\n")
  while true:
    let buf = asyncRead(fd)
    if buf.len > 0:
      asyncWrite(fd, "You sent " & $buf.len & " characters\n")
    else:
      echo "Client went away"
      break

# Coroutine handling the server socket

proc doServer(task: TaskBase) =
  let fd = task.MyTask.fd
  while true:
    waitForEvent(fd, POLLIN)
    var sa: Sockaddr_in
    var saLen: SockLen
    let fdc = posix.accept(fd, cast[ptr SockAddr](sa.addr), saLen.addr)
    echo "Accepted new client"
    newCoro(doClient, MyTask(fd: fdc))

# Create TCP server socket and coroutine

let fd = posix.socket(AF_INET, SOCK_STREAM, 0)
var sa: Sockaddr_in
sa.sin_family = AF_INET.uint16
sa.sin_port = htons(port.uint16)
sa.sin_addr.s_addr = INADDR_ANY
discard bindSocket(fd, cast[ptr SockAddr](sa.addr), sizeof(sa).SockLen)
discard listen(fd, SOMAXCONN)

discard newCoro(doServer, MyTask(fd: fd))

echo "TCP server ready on port ", port

# Forever run the event loop
evq.run()

