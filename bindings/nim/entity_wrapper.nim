import ./flecs
import ./component_wrapper

type
  Entity* = object
    id*: entity_id_t

proc createEntity*(name: string): Entity =
  let id = flecs_entity_create(name)
  if id == 0:
    raise newException(ValueError, "entity_create failed for " & name)
  return Entity(id: id)

proc wrapEntity*(id: entity_id_t): Entity =
  Entity(id: id)

proc destroy*(entity: Entity): bool =
  flecs_entity_destroy(entity.id)

proc add*(entity: Entity, comp: Component): bool =
  flecs_entity_add_component(entity.id, comp.id)

proc add*(entity: Entity, compId: component_id_t): bool =
  flecs_entity_add_component(entity.id, compId)

proc add*(entity: Entity, name: string): bool =
  flecs_entity_add_component_by_name(entity.id, name)

proc remove*(entity: Entity, comp: Component): bool =
  flecs_entity_remove_component(entity.id, comp.id)

proc remove*(entity: Entity, compId: component_id_t): bool =
  flecs_entity_remove_component(entity.id, compId)

proc remove*(entity: Entity, name: string): bool =
  flecs_entity_remove_component_by_name(entity.id, name)

proc has*(entity: Entity, comp: Component): bool =
  flecs_entity_has_component(entity.id, comp.id)

proc has*(entity: Entity, compId: component_id_t): bool =
  flecs_entity_has_component(entity.id, compId)

proc has*(entity: Entity, name: string): bool =
  flecs_entity_has_component_by_name(entity.id, name)

proc set*[T](entity: Entity, comp: Component, value: T): bool =
  var tmp = value
  flecs_entity_set_component(entity.id, comp.id, addr tmp)

proc set*[T](entity: Entity, comp: Component, value: ptr T): bool =
  flecs_entity_set_component(entity.id, comp.id, value)

proc get*[T](entity: Entity, comp: Component): ptr T =
  cast[ptr T](flecs_entity_get_component(entity.id, comp.id))

proc mark*(entity: Entity, comp: Component) =
  flecs_entity_mark_component(entity.id, comp.id)

proc mark*(entity: Entity, compId: component_id_t) =
  flecs_entity_mark_component(entity.id, compId)

proc mark*(entity: Entity, name: string) =
  let id = componentId(name)
  if id == 0:
    raise newException(ValueError, "Unknown component name: " & name)
  flecs_entity_mark_component(entity.id, id)
