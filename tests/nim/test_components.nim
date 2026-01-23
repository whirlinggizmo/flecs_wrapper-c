import std/math
import std/unittest

import bindings/nim/init
import test_common

type
  Position = object
    x, y: cfloat

suite "components":
  test "add and set component + tag":
    withFlecs:
      let pos = createComponent[Position]("NimTestPos")
      let tag = createTag("NimTestTag")
      check pos.id != 0
      check not pos.isTag()
      check tag.id != 0
      check tag.isTag()

      let posFetch = requireComponent("NimTestPos")
      check posFetch.id == pos.id

      let e = createEntity("NimAddEntity")
      check not has(e, pos)
      check add(e, pos)
      check has(e, pos)
      check add(e, "NimTestTag")
      check has(e, "NimTestTag")

      check set(e, pos, Position(x: 1.5, y: -2.0))
      let p = get[Position](e, pos)
      check p != nil
      check abs(p[].x - 1.5) < 1e-6
      check abs(p[].y - -2.0) < 1e-6

      mark(e, pos)

  test "remove tag by name":
    withFlecs:
      let tag = createTag("NimTestTag")
      let e = createEntity("NimRemoveEntity")
      discard add(e, tag)
      check has(e, "NimTestTag")
      discard remove(e, "NimTestTag")
      check not has(e, "NimTestTag")
