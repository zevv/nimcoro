import coro

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


# vi: ft=nim ts=2 sw=2
