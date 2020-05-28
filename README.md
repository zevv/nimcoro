
This is a little proof-of-concept prject to see if I can get Lua-style
coroutines semantics in Nim, and use this to build an alternative async
implementation. It's built on very low level primitives only: the `posix` lib
for sockets and `poll()`, and a small wrapper around the posix `ucontext`
functions.

There's a few moving parts in this project:

- coro.nim: This implements simple coroutines based on ucontext. This are
  basically Lua-style coroutines, but because of Nims static typing it is hard
  to implement the Lua way of passing data through `yield()` and `resume()`.
  For now I've chosen not to pass data at all, as there are enough other ways
  to do that outside of the core coroutine

- evq.nim: This is a very basic and naive event loop implementation: register
  file descriptors with read or write events and a proc, and your proc will
  be called back when the file descriptor is ready.
 
- main.nim: Here the above two modules come together to create very friendly
  async I/O. Look at the `waitForFd()` proc to see what is happening. This
  example creates a listening TCP socket which can handle multiple clients,
  which are all run inside coroutines.

Note that the curent coro implementation confuses Nim's GC, run with `--gc:arc`!

