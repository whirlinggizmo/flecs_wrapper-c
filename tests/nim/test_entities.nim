import std/math
import std/unittest

import bindings/nim/flecs
import test_common

type
  Position = object
    x, y: cfloat

suite "entities":
  test "create, add/remove, set/get":
    withFlecs:
      let pos = createComponent[Position]("NimEntPos")
      let tag = createTag("NimEntTag")

      let e = createEntity("NimEntity")
      check e.id != 0
      check not has(e, "NimEntTag")
      check add(e, "NimEntTag")
      check has(e, "NimEntTag")
      check remove(e, "NimEntTag")
      check not has(e, "NimEntTag")

      check set(e, pos, Position(x: 2.0, y: -1.0))
      let p = get[Position](e, pos)
      check p != nil
      check abs(p[].x - 2.0) < 1e-6
      check abs(p[].y - -1.0) < 1e-6

      let rel = createComponent[Position]("NimPairRel")
      let obj = createEntity("NimPairObj")

      check not hasPair(e, rel, obj)
      check addPair(e, rel, obj)
      check hasPair(e, rel, obj)

      check setPair(e, rel, obj, Position(x: 7.0, y: 8.0))
      let pp = getPair[Position](e, rel, obj)
      check pp != nil
      check abs(pp[].x - 7.0) < 1e-6
      check abs(pp[].y - 8.0) < 1e-6

      check removePair(e, rel, obj)
      check not hasPair(e, rel, obj)
      check destroy(obj)

      check destroy(e)
