import std/unittest

import bindings/nim/flecs

var systemSeen = 0
proc systemCb(
  entity_ids: ptr entity_id_t,
  entity_count: uint32,
  columns: ptr pointer,
  column_component_ids: ptr component_id_t,
  column_sizes: ptr uint32,
  column_count: uint32,
  delta_time: float32,
  callback_id: uint32,
) {.cdecl.} =
  inc systemSeen

var observerSeen = 0
var observerEvent: event_id_t = 0
var observerComp: component_id_t = 0
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
  inc observerSeen
  observerEvent = event_id
  observerComp = component_id

suite "flecs core":
  test "init, component, entity":
    flecs_init()
    defer: flecs_fini()
    flecs_set_threads(1)

    let compId: component_id_t = c_flecs_component_create("CorePos", cast[uint32](8))
    check compId != 0
    check flecs_component_get_id_by_name("CorePos") == compId

    let tagId: component_id_t = flecs_component_create_tag("CoreTag")
    check tagId != 0
    check flecs_component_is_tag(tagId)

    let eId: entity_id_t = flecs_entity_create("CoreEntity")
    check eId != 0
    check not flecs_entity_has_component_by_name(eId, "CoreTag")
    check flecs_entity_add_component_by_name(eId, "CoreTag")
    check flecs_entity_has_component_by_name(eId, "CoreTag")
    check flecs_entity_remove_component_by_name(eId, "CoreTag")
    check not flecs_entity_has_component_by_name(eId, "CoreTag")

    check flecs_entity_destroy(eId)

  test "system callback runs":
    flecs_init()
    defer: flecs_fini()
    flecs_set_threads(1)

    systemSeen = 0
    let compId: component_id_t = c_flecs_component_create("CoreSysPos", cast[uint32](8))
    check compId != 0

    let eId: entity_id_t = flecs_entity_create("CoreSysEntity")
    check eId != 0
    check flecs_entity_add_component(eId, compId)

    var comps = [compId]
    let sysId: system_id_t = flecs_register_system(
      "CoreSys",
      comps[0].addr,
      1'u32,
      systemCb,
      1'u32,
    )
    check sysId != 0

    flecs_progress(0.5)
    check systemSeen >= 1

    discard flecs_entity_destroy(eId)

  test "observer fires on add":
    flecs_init()
    defer: flecs_fini()
    flecs_set_threads(1)

    observerSeen = 0
    observerEvent = 0
    observerComp = 0

    let compId: component_id_t = c_flecs_component_create("CoreObsPos", cast[uint32](8))
    check compId != 0

    var comps = [compId]
    var events = [ecsOnAdd]
    let obsId: observer_id_t = flecs_register_observer(
      comps[0].addr,
      1'u32,
      events[0].addr,
      1'u32,
      observerCb,
      1'u32,
    )
    check obsId != 0

    let eId: entity_id_t = flecs_entity_create("CoreObsEntity")
    check eId != 0
    check flecs_entity_add_component(eId, compId)

    flecs_progress(0)
    check observerSeen >= 1
    check observerEvent == ecsOnAdd
    check observerComp == compId

    discard flecs_entity_destroy(eId)
