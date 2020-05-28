import ucontext

const stackSize = 32768

type

  CoroException* = object of CatchableError

  CoroStatus* = enum
    csRunning,    # running, i.e. it called status()
    csSuspended,  # suspended into a jield()
    csNormal,     # active but not running (resumed another coro)
    csDead        # finished or stopped with an exception

  Coro* = ref object
    ctx: ucontext_t
    stack: array[stackSize, uint8]
    fn: CoroFn
    status*: CoroStatus
    caller: Coro         # The coroutine resuming us
    task: TaskBase

  CoroFn = proc(t: TaskBase)

  TaskBase* = ref object of RootObj

var coroMain {.threadvar.}: Coro  # The "main" coroutine, which is actually not a coroutine
var coroCur {.threadVar.}: Coro   # The current active coroutine.

proc jield*()
proc resume*(coro: Coro)


# makecontext() target

proc schedule(coro: Coro) {.cdecl.} =
  coro.fn(coro.task)
  coro.status = csDead
  jield()


proc newCoro*(fn: CoroFn, task: TaskBase, start=true): Coro {.discardable.} =
  ## Create a new coroutine with body `fn`. If `start` is true the coroutine
  ## will be executed right away
  let coro = Coro(fn: fn, status: csSuspended, task: task)
  coro.ctx.uc_stack.ss_sp = coro.stack[0].addr
  coro.ctx.uc_stack.ss_size = coro.stack.len

  let r = getcontext(coro.ctx)
  doAssert(r == 0)
  makecontext(coro.ctx, schedule, 1, coro);

  if start:
    coro.resume()

  return coro


proc resume*(coro: Coro) =
  ## Starts or continues the execution of coroutine co. The first time you
  ## resume a coroutine, it starts running its body. If the coroutine has
  ## yielded, resume restarts it.
  assert coro != nil
  assert coroCur != nil
  assert coroCur.status == csRunning

  if coro.status != csSuspended:
    let msg = "cannot resume coroutine with status " & $coro.status
    echo(msg)
    raise newException(CoroException, msg)

  coro.caller = coroCur
  coroCur.status = csNormal

  coro.status = csRunning
  let coroPrev = coroCur
  coroCur = coro

  let frame = getFrameState()
  let r = swapcontext(coro.caller.ctx, coro.ctx)  # Does not return until coro yields
  assert(r == 0)
  setFrameState(frame)

  coroCur = coroPrev
  if coroCur != nil:
    coroCur.status = csRunning


proc jield*() =
  ## Suspends the execution of the calling coroutine.
  let coro = coroCur
  assert coro != nil
  assert coro.status in {csRunning, csDead}

  if coro.status == csRunning:
    coro.status = csSuspended

  let frame = getFrameState()
  let r = swapcontext(coro.ctx, coro.caller.ctx) # Does not return until coro resumes
  assert(r == 0)
  setFrameState(frame)


proc running*(): Coro =
  ## Return the currently running coro
  coroCur


coroMain = Coro(status: csRunning)
coroCur = coroMain

# vi: ft=nim ts=2 sw=2
