# Threading Guidance for ofxGgmlCore

`ofxGgmlCore` keeps its public API synchronous by design, but it does not force
an all-application threading model. The API needs to be safe when used from
companion apps that do work on background threads.

## What Core protects

- Backend swap operations (`setBackend`, `set*Function`) are serialized with
  internal mutexes.
- Callback reads are copied before invocation so they can be replaced safely.
- Backend pointers are copied under lock before each call, then the call runs
  without holding that internal lock.

Core does not assume GL context ownership inside inference callbacks. Treat any
model callback and request/response handling as CPU work.

## What Core does not protect

- OpenGL/surface calls should still stay on the GL thread.
- If your callback mutates shared data, you must synchronize that data yourself.
- Model runtimes that are not explicitly documented as thread-safe should not be
  called from multiple worker threads simultaneously.

## Recommended openFrameworks application pattern

Use a background thread (or `ofThread`) for long-running inference and use the
main thread for rendering and OpenGL object updates. This follows openFrameworks
`ofThread` guidance: offload heavy work from `update`/`draw`, keep GL calls in the
main loop, and use mutexes/scoped locks for shared buffers.

`ofThread` is documented in:
https://openframeworks.cc/ofBook/chapters/threads.html
