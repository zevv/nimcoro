import coro

proc maker(val: int): int 
proc producer(val: int): int 


let com = newCoro(maker)
let cop = newCoro(producer)

proc dump(s: string) =
  echo s, " com:", com.status, ", cop:", cop.status


proc maker(val: int): int =
  dump "maker1"
  while true:
    dump "maker2"
    discard jield(42)
    dump "maker3"

proc producer(val: int): int =
  dump "proc1"
  for i in 0..2:
    echo "pre"
    let v = com.resume(10)
    echo "v = ", v
    discard jield(i) + v
    echo "post"
  echo "I'm dead"


for i in 0..8:
  dump "main" & $i
  echo "cop ", i, " = ", cop.resume(10)
  echo cop.status

dump "end"

# vi: ft=nim ts=2 sw=2
