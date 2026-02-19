import ./flecs_wrapper
import ./flecs_component
import ./flecs_entity

type
  Pair* = object
    id*: pair_id_t

proc registerPair*(relation: Component, obj: Entity): Pair =
  let pid = flecs_pair_register(relation.id, obj.id)
  if pid == 0:
    raise newException(ValueError, "pair_register failed")
  Pair(id: pid)

proc registerPairEntity*(relation: Entity, obj: Entity): Pair =
  let pid = flecs_pair_register_entity(relation.id, obj.id)
  if pid == 0:
    raise newException(ValueError, "pair_register failed")
  Pair(id: pid)

proc registerPairByName*(relationName: string, objectName: string): Pair =
  let pid = flecs_pair_register_by_name(cstring(relationName), cstring(objectName))
  if pid == 0:
    raise newException(ValueError, "pair_register failed")
  Pair(id: pid)

proc unregisterPair*(pair: Pair): bool =
  flecs_pair_unregister(pair.id)

proc unregisterPairId*(pairId: pair_id_t): bool =
  flecs_pair_unregister(pairId)
