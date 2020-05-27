import coro
import nativesockets
import eventqueue

var evq: Evq

proc doClient(cmd: string): string =
  echo "> cmd: ", cmd

  var buf: string
  while true:
    let buf = jield "> "
    echo "> buf: ", buf


proc doServer() =
  let fdServer = newNativeSocket()
  var sa: Sockaddr_in
  sa.sin_family = AF_INET.uint16
  sa.sin_port = htons(9000)
  sa.sin_addr.s_addr = INADDR_ANY
  discard fdServer.bindAddr(cast[ptr SockAddr](sa.addr), sizeof(sa).SockLen)
  discard fdServer.listen(SOMAXCONN)

  evq.addFd(fdServer.int, proc() =
    let (fdClient, st) = fdServer.accept()
    echo fdClient.repr, " ", st.repr

    let co = newCoro("client", doClient)

    evq.addFd(fdClient.int, proc() =
      var buf = newString(100)
      let r = recv(fdClient, buf[0].addr, buf.len, 0)
      if r == 0: return
      buf.setlen(r)
      var resp = co.resume(buf)
      discard send(fdClient, resp[0].addr, resp.len, 0)
    )

  )



doServer()

evq.run()

