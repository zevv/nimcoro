import ucontext

type

  CoroStatus* = enum
    csRunning,    # running, i.e. it called status()
    csSuspended,  # suspended into a jield()
    csNormal,     # active but not running (resumed another coro)
    csDead        # finished or stopped with an exception

  CoroObj* = object
    ctx: ucontext_t
    ctxPrev: ucontext_t
    stack: seq[uint8]
    fn: CoroFn
    valResume: int
    valYiel: int
    status*: CoroStatus

  Coro* = ref CoroObj

  CoroFn = proc(val: int): int


var coroThis {.threadVar.}: Coro

proc schedule(coro: Coro) {.cdecl.}

proc newCoro*(fn: CoroFn, stackSize=16384): Coro =
  let coro = Coro()
  coro.stack.setLen(stackSize)
  coro.ctx.uc_stack.ss_sp = coro.stack[0].addr
  coro.ctx.uc_stack.ss_size = stackSize
  coro.fn = fn
  coro.status = csSuspended
  let r = getcontext(coro.ctx)
  makecontext(coro.ctx, schedule, 1, coro);
  doAssert(r == 0)
  return coro

proc resume*(coro: Coro, val: int): int =
  if coroThis != nil:
    coroThis.status = csNormal

  coro.valResume = val
  coro.status = csRunning
  let coroPrev = coroThis
  coroThis = coro
  let r = swapcontext(coro.ctxPrev, coro.ctx)
  assert(r == 0)
  coroThis = coroPrev
  return coro.valYiel

proc jield*(coro: Coro, val: int): int =
  assert coro != nil
  coro.valYiel = val
  coro.status = csSuspended
  let r = swapcontext(coro.ctx, coro.ctxPrev)
  assert(r == 0)
  return val

proc jield*(val: int): int =
  coroThis.jield(val)

proc schedule(coro: Coro) {.cdecl.} =
  let r = coro.fn(coro.valResume)
  echo coro.jield 0


# vi: ft=nim ts=2 sw=2
