import std/unittest

import bindings/nim/flecs
import test_common

suite "remove components":
  test "remove tag by name":
    withFlecs:
      let tag = createTag("NimTestTag")
      let e = createEntity("NimRemoveEntity")
      discard add(e, tag)
      check has(e, "NimTestTag")
      discard remove(e, "NimTestTag")
      check not has(e, "NimTestTag")
