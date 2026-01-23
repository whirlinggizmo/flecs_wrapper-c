import std/macros

import ./flecs

type
  Component* = object
    name*: string
    id*: component_id_t
    size*: uint32

macro typeName(T: typedesc): untyped =
  newLit(repr(T))

# High-level macro for registration
macro flecs_component_create*(T: typedesc): untyped =
  let typeName = repr(T)
  quote:
    c_flecs_component_create(`typeName`, cast[uint32](sizeof(`T`)))

proc componentId*(name: string): component_id_t =
  flecs_component_get_id_by_name(name)

proc getComponent*(name: string): Component =
  let id = componentId(name)
  if id == 0:
    return Component(name: "", id: 0, size: 0)
  return Component(name: name, id: id, size: 0)

proc requireComponent*(name: string): Component =
  let comp = getComponent(name)
  if comp.id == 0:
    raise newException(ValueError, "Unknown component name: " & name)
  return comp

proc createComponent*[T](name: string = ""): Component =
  var compName = name
  if compName.len == 0:
    compName = typeName(T)
  let id = c_flecs_component_create(cstring(compName), cast[uint32](sizeof(T)))
  if id == 0:
    raise newException(ValueError, "component_create failed for " & compName)
  return Component(name: compName, id: id, size: cast[uint32](sizeof(T)))

proc createTag*(name: string): Component =
  let id = flecs_component_create_tag(cstring(name))
  if id == 0:
    raise newException(ValueError, "component_create_tag failed for " & name)
  return Component(name: name, id: id, size: 0)

proc isTag*(comp: Component): bool =
  flecs_component_is_tag(comp.id)
