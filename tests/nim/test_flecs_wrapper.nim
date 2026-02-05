import std/unittest

import bindings/nim/flecs

type Vec2 = object
  x: float32
  y: float32

var seenAdd = 0
var seenSet = 0
var lastEvent: event_id_t = 0
var lastComp: component_id_t = 0
var lastEntity: entity_id_t = 0
var lastX: float32 = 0
var lastY: float32 = 0

proc observerCb(
  entity_ids: ptr entity_id_t,
  entity_count: uint32,
  columns: ptr pointer,
  column_component_ids: ptr component_id_t,
  column_sizes: ptr uint32,
  column_count: uint32,
  event_id: event_id_t,
  component_id: component_id_t,
  callback_id: uint32,
) {.cdecl.} =
  if callback_id != 123'u32:
    return

  if entity_count == 0'u32 or column_count == 0'u32:
    return

  lastEvent = event_id
  lastComp = component_id

  let entArr = cast[ptr UncheckedArray[entity_id_t]](entity_ids)
  lastEntity = entArr[0]

  let compArr = cast[ptr UncheckedArray[component_id_t]](column_component_ids)
  let sizeArr = cast[ptr UncheckedArray[uint32]](column_sizes)
  let colArr = cast[ptr UncheckedArray[pointer]](columns)

  if colArr[0] != nil:
    let vptr = cast[ptr Vec2](colArr[0])
    lastX = vptr[].x
    lastY = vptr[].y

  if event_id == ecsOnAdd:
    inc seenAdd
  elif event_id == ecsOnSet:
    inc seenSet

suite "flecs wrapper core":
  test "low level component/entity/observer":
    flecs_init()
    defer: flecs_fini()
    flecs_set_threads(1)

    seenAdd = 0
    seenSet = 0
    lastEvent = 0
    lastComp = 0
    lastEntity = 0
    lastX = 0
    lastY = 0

    let compId: component_id_t = c_flecs_component_create("CoreVec2", cast[uint32](sizeof(Vec2)))
    check compId != 0
    check flecs_component_get_id_by_name("CoreVec2") == compId
    check not flecs_component_is_tag(compId)

    let eId: entity_id_t = flecs_entity_create("CoreEntity")
    check eId != 0
    check not flecs_entity_has_component(eId, compId)

    var v1 = Vec2(x: 1, y: 2)
    check flecs_entity_set_component(eId, compId, addr v1)
    check flecs_entity_has_component(eId, compId)

    let compPtr = flecs_entity_get_component(eId, compId)
    check compPtr != nil
    let vptr = cast[ptr Vec2](compPtr)
    check vptr[].x == 1
    check vptr[].y == 2

    var comps = [compId]
    var events = [ecsOnAdd, ecsOnSet]
    let obsId: observer_id_t = flecs_register_observer(
      comps[0].addr,
      1'u32,
      events[0].addr,
      2'u32,
      observerCb,
      123'u32,
    )
    check obsId != 0

    var v2 = Vec2(x: 3, y: 4)
    check flecs_entity_set_component(eId, compId, addr v2)

    var v3 = Vec2(x: 5, y: 6)
    check flecs_entity_set_component(eId, compId, addr v3)

    flecs_progress(0)

    check lastComp == compId
    check lastEntity == eId
    check seenSet >= 1
    check lastX == 5
    check lastY == 6

    check flecs_unregister_observer(obsId)

    var badEvents = [99'u32]
    let badObs: observer_id_t = flecs_register_observer(
      comps[0].addr,
      1'u32,
      badEvents[0].addr,
      1'u32,
      observerCb,
      999'u32,
    )
    check badObs == 0

    check flecs_entity_destroy(eId)
