import coro
import nativesockets

proc maker(val: int): int 
proc producer(val: int): int 


let com = newCoro("maker", maker)
let cop = newCoro("producer", producer)

proc maker(val: int): int =
  while true:
    echo "maker got ",  jield(42)

proc producer(val: int): int =
  for i in 0..2:
    let v = com.resume(10)
    echo "v = ", v
    discard jield(i + v)
  echo "Dying"
  return -1


for i in 0..8:
  echo "cop ", i, " = ", cop.resume(10)
  echo ""



#let s = newNativeSocket()
#var sa: Sockaddr_in
#sa.sin_family = AF_INET.uint16
#sa.sin_port = htons(9000)
#sa.sin_addr.s_addr = INADDR_ANY
#discard s.bindAddr(cast[ptr SockAddr](sa.addr), sizeof(sa).SockLen)

# vi: ft=nim ts=2 sw=2
