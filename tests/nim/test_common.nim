import bindings/nim/flecs

template withFlecs*(body: untyped) =
  flecs_init()
  defer: flecs_fini()
  flecs_set_threads(1)
  body
