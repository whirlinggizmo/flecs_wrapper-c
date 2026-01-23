import std/unittest

import bindings/nim/flecs
import test_common

type
  Position = object
    x, y: cfloat

suite "observers":
  test "on add observer fires and exclusions work":
    withFlecs:
      let pos = createComponent[Position]("NimTestPos")
      let tag = createTag("NimTestTag")
      let posId = pos.id
      let tagId = tag.id

      var obsSeen = 0
      var lastEntity: entity_id_t = 0
      var lastComponent: component_id_t = 0
      let obsId = addObserver([posId], [ecsOnAdd], proc(it: ObserverIter) {.gcsafe, closure.} =
        inc obsSeen
        lastEntity = entity(it, 0)
        lastComponent = it.componentId
      )
      check obsId != 0

      let e = createEntity("ObsEntity")
      discard set(e, pos, Position(x: 3.0, y: 4.0))

      flecs_progress(0)
      check obsSeen >= 1
      check lastEntity == e.id
      check lastComponent == posId

      var obsExSeen = 0
      let obsExId = addObserverEx([posId], [tagId], [ecsOnAdd], proc(it: ObserverIter) {.gcsafe, closure.} =
        inc obsExSeen
      )
      check obsExId != 0

      let e4 = createEntity("ObsExEntity1")
      discard set(e4, pos, Position(x: 1.0, y: 1.0))
      let e5 = createEntity("ObsExEntity2")
      discard add(e5, tag)
      discard set(e5, pos, Position(x: 2.0, y: 2.0))

      flecs_progress(0)
      check obsExSeen == 1

      expect CatchableError:
        discard addObserver([posId], [0'u32], proc(it: ObserverIter) {.gcsafe, closure.} = discard)
