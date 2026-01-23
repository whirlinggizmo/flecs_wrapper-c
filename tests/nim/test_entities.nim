import std/math
import std/unittest

import bindings/nim/init
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

      check destroy(e)
