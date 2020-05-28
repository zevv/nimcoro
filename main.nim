import coro
import posix
import times
import eventqueue
import io

let port = 9000
var evq: Evq

type
  MyTask* = ref object of TaskBase
    fd: SocketHandle

# Coroutine handling one client connection.

proc doClient(task: TaskBase) =
  let fd = task.Mytask.fd
  ioWrite(fd, "Hello! Please type something.\n")
  while true:
    let buf = ioRead(fd)
    if buf.len > 0:
      ioWrite(fd, "You sent " & $buf.len & " characters\n")
    else:
      echo "Client went away"
      break

# Coroutine handling the server socket

proc doServer(task: TaskBase) =
  let fd = task.MyTask.fd
  while true:
    waitForFd(fd, POLLIN)
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

# Just for fun, create a tick tock coroutine

proc doTick(task: TaskBase) =
  var n = 0
  while true:
    echo "tick ", n
    inc n
    jield()
 
let co = newCoro(doTick)
discard addTimer(1.0, proc(): bool = co.resume())


# Forever run the event loop
run()

