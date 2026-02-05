import std/unittest

import bindings/nim/flecs

type Vec2 = object
  x: float32
  y: float32

suite "pair wrapper":
  test "register/unregister":
    flecs_init()
    defer: flecs_fini()
    flecs_set_threads(1)

    let rel = createComponent[Vec2]("NimPairRel")
    let obj = createEntity("NimPairObj")
    let host = createEntity("NimPairHost")

    let pair = registerPair(rel, obj)
    check pair.id != 0
    check not flecs_entity_has_pair(host.id, pair.id)
    check flecs_entity_add_pair(host.id, pair.id)
    check flecs_entity_has_pair(host.id, pair.id)
    check flecs_entity_remove_pair(host.id, pair.id)
    check not flecs_entity_has_pair(host.id, pair.id)

    check unregisterPair(pair)
    check not flecs_entity_add_pair(host.id, pair.id)
