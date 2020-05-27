import ucontext

type
  
  CoroException* = object of CatchableError

  CoroStatus* = enum
    csRunning,    # running, i.e. it called status()
    csSuspended,  # suspended into a jield()
    csNormal,     # active but not running (resumed another coro)
    csDead        # finished or stopped with an exception

  Coro* = ref object
    name: string
    arg: int
    ctx: ucontext_t
    ctxPrev: ucontext_t
    stack: seq[uint8]
    fn: CoroFn
    status*: CoroStatus
    resumer: Coro         # The coroutine resuming us

  CoroFn = proc(coro: Coro, arg: int)


var coroMain {.threadvar.}: Coro
var coroCur {.threadVar.}: Coro


proc schedule(coro: Coro) {.cdecl.}
proc resume*(coro: Coro)


proc newCoro*(name: string, fn: CoroFn, arg: int): Coro =
  let coro = Coro()

  coro.name = name
  coro.fn = fn
  coro.arg = arg

  coro.stack.setLen(32768)
  coro.ctx.uc_stack.ss_sp = coro.stack[0].addr
  coro.ctx.uc_stack.ss_size = coro.stack.len
  coro.status = csSuspended
  let r = getcontext(coro.ctx)
  makecontext(coro.ctx, schedule, 1, coro);
  doAssert(r == 0)

  coro.resume()

  return coro


proc `$`*(coro: Coro): string =
  coro.name & ":" & $coro.status


proc resume*(coro: Coro) =
  #echo "resume ", coroCur, " -> ", coro

  assert coro != nil
  assert coroCur != nil
  assert coroCur.status == csRunning
  
  if coro.status != csSuspended:
    let msg = "cannot resume coroutine " & $coro
    echo(msg)
    raise newException(CoroException, msg)

  coro.resumer = coroCur
  coroCur.status = csNormal

  coro.status = csRunning
  let coroPrev = coroCur
  coroCur = coro

  let frame = getFrameState()
  let r = swapcontext(coro.resumer.ctx, coro.ctx)  # Does not return until coro yields
  assert(r == 0)
  setFrameState(frame)

  coroCur = coroPrev
  if coroCur != nil:
    coroCur.status = csRunning


proc jield*() =
  let coro = coroCur
  #echo "jield ", coro, " -> ", coro.resumer

  assert coro != nil
  assert coro.status in {csRunning, csDead}

  if coro.status == csRunning:
    coro.status = csSuspended

  let frame = getFrameState()
  let r = swapcontext(coro.ctx, coro.resumer.ctx) # Does not return until coro resumes
  assert(r == 0)
  setFrameState(frame)



proc schedule(coro: Coro) {.cdecl.} =
  coro.fn(coro, coro.arg)
  coro.status = csDead
  jield()


coroMain = Coro(name: "main", status: csRunning)
coroCur = coroMain

# vi: ft=nim ts=2 sw=2
