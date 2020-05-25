
type
  stack_t* {.importc, header: "<ucontext.h>".} = object
    ss_sp*: pointer
    ss_flags*: int
    ss_size*: int

  ucontext_t* {.importc, header: "<ucontext.h>".} = object
    uc_link*: ptr ucontext_t
    uc_stack*: stack_t


proc getcontext*(context: var ucontext_t): int32 {.importc, header: "<ucontext.h>".}
proc setcontext*(context: var ucontext_t): int32 {.importc, header: "<ucontext.h>".}
proc swapcontext*(fromCtx, toCtx: var ucontext_t): int32 {.importc, header: "<ucontext.h>".}
proc makecontext*(context: var ucontext_t, fn: pointer, argc: int32) {.importc, header: "<ucontext.h>", varargs.}


