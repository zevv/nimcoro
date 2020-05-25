import ucontext

type
  
  CoroException* = object of CatchableError

  CoroStatus* = enum
    csRunning,    # running, i.e. it called status()
    csSuspended,  # suspended into a jield()
    csNormal,     # active but not running (resumed another coro)
    csDead        # finished or stopped with an exception

  CoroObj* = object
    name: string
    ctx: ucontext_t
    ctxPrev: ucontext_t
    stack: seq[uint8]
    fn: CoroFn
    valResume: int
    valJield: int
    status*: CoroStatus

  Coro* = ref CoroObj

  CoroFn = proc(val: int): int


var coroMain {.threadvar.}: Coro
var coroCur {.threadVar.}: Coro


proc schedule(coro: Coro) {.cdecl.}


proc newCoro*(name: string, fn: CoroFn, stackSize=16384): Coro =
  let coro = Coro()
  coro.name = name
  coro.stack.setLen(stackSize)
  coro.ctx.uc_stack.ss_sp = coro.stack[0].addr
  coro.ctx.uc_stack.ss_size = stackSize
  coro.fn = fn
  coro.status = csSuspended
  let r = getcontext(coro.ctx)
  makecontext(coro.ctx, schedule, 1, coro);
  doAssert(r == 0)
  return coro


proc `$`*(coro: Coro): string =
  coro.name & ":" & $coro.status


proc resume*(coro: Coro, val: int): int =
  echo "resume ", coroCur, " -> ", coro

  assert coro != nil
  assert coroCur != nil
  assert coroCur.status == csRunning

  if coroCur != nil:
    coroCur.status = csNormal

  if coro.status != csSuspended:
    echo "Can not resume " & $coro
    raise newException(CoroException, "Can not resume " & $coro)

  coro.valResume = val
  coro.status = csRunning
  let coroPrev = coroCur
  coroCur = coro

  let frame = getFrameState()
  let r = swapcontext(coro.ctxPrev, coro.ctx)  # Does not return until coro yields
  assert(r == 0)
  setFrameState(frame)

  coroCur = coroPrev
  if coroCur != nil:
    coroCur.status = csRunning
  return coro.valJield


proc jield*(val: int): int =
  let coro = coroCur
  echo "jield ", coro

  assert coro != nil
  assert coro.status == csRunning

  coro.valJield = val
  if coro.status == csRunning:
    coro.status = csSuspended

  let frame = getFrameState()
  let r = swapcontext(coro.ctx, coro.ctxPrev) # Does not return until coro resumes
  assert(r == 0)
  setFrameState(frame)

  echo "swapped ", coroCur
  return val


proc schedule(coro: Coro) {.cdecl.} =
  let val = coro.fn(coro.valResume)
  coro.status = csDead
  echo "dead ", coro
  echo jield val


coroMain = newCoro("main", nil)
coroMain.status = csRunning
coroCur = coroMain

# vi: ft=nim ts=2 sw=2
