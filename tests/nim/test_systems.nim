import std/math
import std/unittest

import bindings/nim/flecs
import test_common

type
  Position = object
    x, y: cfloat

  Velocity = object
    x, y: cfloat

suite "systems":
  test "system updates position":
    withFlecs:
      let pos = createComponent[Position]("NimTestPos")
      let vel = createComponent[Velocity]("NimTestVel")
      let posId = pos.id
      let velId = vel.id

      let e = createEntity("NimSystemEntity")
      discard set(e, pos, Position(x: 0.0, y: 0.0))
      discard set(e, vel, Velocity(x: 2.0, y: 0.0))

      var sysSeen = 0
      let sysId = addSystem("NimMove", [posId, velId], proc(it: SystemIter) {.gcsafe, closure.} =
        for i in 0 ..< int(it.count):
          let p = col[Position](it, posId, i)
          let v = col[Velocity](it, velId, i)
          if p != nil and v != nil:
            p[].x += v[].x * it.dt
            inc sysSeen
      )
      check sysId != 0

      flecs_progress(0.5)
      let p2 = get[Position](e, pos)
      check p2 != nil
      check abs(p2[].x - 1.0) < 1e-6
      check sysSeen >= 1

      check unregister_system(sysId)
