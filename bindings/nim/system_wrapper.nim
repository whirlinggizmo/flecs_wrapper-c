import std/tables

import ./flecs
import ./component_wrapper

type
  SystemIter* = object
    entityIds*: ptr UncheckedArray[entity_id_t]
    count*: uint32
    columns*: seq[pointer]
    columnComponentIds*: seq[component_id_t]
    columnSizes*: seq[uint32]
    dt*: float32
    callbackId*: uint32

  SystemIterCallback* = proc(it: SystemIter) {.gcsafe, closure.}

type SystemCallback = proc(
  entities: ptr UncheckedArray[entity_id_t],
  columns: seq[pointer],
  columnComponentIds: seq[component_id_t],
  columnSizes: seq[uint32],
  count: uint32,
  delta_time: float32,
) {.gcsafe.}

var
  nextSystemCallbackId {.threadvar.}: uint32
  systemCallbackMap {.threadvar.}: Table[uint32, SystemCallback]
  systemCbInited {.threadvar.}: bool

proc ensureSystemCbInit() {.inline.} =
  if not systemCbInited:
    systemCbInited = true
    nextSystemCallbackId = 1'u32 # Reserve 0 for invalid ID
    systemCallbackMap = initTable[uint32, SystemCallback]()

proc register_system_callback(cb: SystemCallback, id: uint32 = 0'u32): uint32 =
  ensureSystemCbInit()
  if cb.isNil:
    echo "⚠️ Warning: tried to register nil callback"
    return 0

  var realId = id
  if realId == 0:
    realId = nextSystemCallbackId
    inc nextSystemCallbackId

  if systemCallbackMap.hasKey(realId):
    echo "⚠️ Warning: callback already registered for id ", realId
    return 0

  systemCallbackMap[realId] = cb
  return realId

proc system_trampoline(
    entity_ids: ptr entity_id_t,
    entity_count: uint32,
    columns: ptr pointer,
    column_component_ids: ptr component_id_t,
    column_sizes: ptr uint32,
    column_count: uint32,
    delta_time: float32,
    callback_id: uint32,
) {.cdecl.} =
  ensureSystemCbInit()
  let entityArr = cast[ptr UncheckedArray[entity_id_t]](entity_ids)
  let columnArr = cast[ptr UncheckedArray[pointer]](columns)
  let columnComponentIdArr = cast[ptr UncheckedArray[component_id_t]](column_component_ids)
  let columnSizeArr = cast[ptr UncheckedArray[uint32]](column_sizes)

  var columnPtrs: seq[pointer] = newSeq[pointer](column_count)
  var columnComponentIds: seq[component_id_t] = newSeq[component_id_t](column_count)
  var columnSizesSeq: seq[uint32] = newSeq[uint32](column_count)

  for i in 0 ..< int(column_count):
    columnPtrs[i] = columnArr[i]
    columnComponentIds[i] = columnComponentIdArr[i]
    columnSizesSeq[i] = columnSizeArr[i]

  if systemCallbackMap.hasKey(callback_id):
    systemCallbackMap[callback_id](
      entityArr,
      columnPtrs,
      columnComponentIds,
      columnSizesSeq,
      entity_count,
      delta_time,
    )
  else:
    echo "⚠️ No callback registered for id ", callback_id

proc flecs_remove_system*(id: system_id_t) =
  ensureSystemCbInit()
  if systemCallbackMap.hasKey(id):
    systemCallbackMap.del(id)
    echo "✅ Callback with id ", id, " unregistered."
  else:
    echo "⚠️ Tried to unregister missing callback id ", id

proc flecs_add_system*(
    name: string, components: openArray[uint32], callback: SystemCallback
): system_id_t =
  ensureSystemCbInit()
  if callback.isNil:
    echo "⚠️ Warning: tried to register nil callback"
    return

  if components.len == 0:
    echo "⚠️ Warning: tried to register system with no components"
    return

  let cbid = register_system_callback(callback)
  let system_id = flecs_register_system(
    name, components[0].addr, uint32 components.len, system_trampoline, cbid
  )
  return system_id

proc flecs_add_task*(
    name: string, callback: SystemCallback
): system_id_t =
  ensureSystemCbInit()
  if callback.isNil:
    echo "⚠️ Warning: tried to register nil callback"
    return

  let cbid = register_system_callback(callback)
  let task_id = flecs_register_system(
    name, nil, 0, system_trampoline, cbid
  )
  return task_id

proc entity*(it: SystemIter, i: int): entity_id_t =
  if i < 0 or i >= int(it.count):
    raise newException(IndexDefect, "entity index out of bounds")
  it.entityIds[i]

proc colIndex(it: SystemIter, compId: component_id_t): int =
  for i in 0 ..< it.columnComponentIds.len:
    if it.columnComponentIds[i] == compId:
      return i
  return -1

proc colPtr*[T](it: SystemIter, compId: component_id_t): ptr UncheckedArray[T] =
  let idx = it.colIndex(compId)
  if idx < 0:
    return nil
  cast[ptr UncheckedArray[T]](it.columns[idx])

proc colPtr*[T](it: SystemIter, comp: Component): ptr UncheckedArray[T] =
  colPtr[T](it, comp.id)

proc col*[T](it: SystemIter, compId: component_id_t, i: int): ptr T =
  let ptrs = colPtr[T](it, compId)
  if ptrs.isNil:
    return nil
  if i < 0 or i >= int(it.count):
    raise newException(IndexDefect, "column index out of bounds")
  addr ptrs[i]

proc col*[T](it: SystemIter, comp: Component, i: int): ptr T =
  col[T](it, comp.id, i)

proc toComponentIds(components: openArray[Component]): seq[component_id_t] =
  result = newSeq[component_id_t](components.len)
  for i, comp in components:
    result[i] = comp.id

proc toComponentIds(components: openArray[string]): seq[component_id_t] =
  result = newSeq[component_id_t](components.len)
  for i, name in components:
    let id = componentId(name)
    if id == 0:
      raise newException(ValueError, "Unknown component name: " & name)
    result[i] = id

proc addSystemIds(name: string, components: openArray[component_id_t], callback: SystemIterCallback): system_id_t =
  if components.len == 0:
    raise newException(ValueError, "System must include at least one component")
  if callback.isNil:
    raise newException(ValueError, "System callback is nil")
  var cbid: uint32
  cbid = register_system_callback(proc(
    entities: ptr UncheckedArray[entity_id_t],
    columns: seq[pointer],
    columnComponentIds: seq[component_id_t],
    columnSizes: seq[uint32],
    count: uint32,
    delta_time: float32,
  ) {.gcsafe.} =
    callback(SystemIter(
      entityIds: entities,
      count: count,
      columns: columns,
      columnComponentIds: columnComponentIds,
      columnSizes: columnSizes,
      dt: delta_time,
      callbackId: cbid,
    ))
  )
  result = flecs_register_system(name, components[0].unsafeAddr, uint32 components.len, system_trampoline, cbid)

proc addSystem*(name: string, components: openArray[Component], callback: SystemIterCallback): system_id_t =
  addSystemIds(name, toComponentIds(components), callback)

proc addSystem*(name: string, components: openArray[string], callback: SystemIterCallback): system_id_t =
  addSystemIds(name, toComponentIds(components), callback)

proc addSystem*(name: string, components: openArray[component_id_t], callback: SystemIterCallback): system_id_t =
  addSystemIds(name, components, callback)

proc addSystemExIds(name: string, includeComponents: openArray[component_id_t], excludeComponents: openArray[component_id_t], callback: SystemIterCallback): system_id_t =
  if includeComponents.len == 0:
    raise newException(ValueError, "System must include at least one component")
  if callback.isNil:
    raise newException(ValueError, "System callback is nil")
  var cbid: uint32
  cbid = register_system_callback(proc(
    entities: ptr UncheckedArray[entity_id_t],
    columns: seq[pointer],
    columnComponentIds: seq[component_id_t],
    columnSizes: seq[uint32],
    count: uint32,
    delta_time: float32,
  ) {.gcsafe.} =
    callback(SystemIter(
      entityIds: entities,
      count: count,
      columns: columns,
      columnComponentIds: columnComponentIds,
      columnSizes: columnSizes,
      dt: delta_time,
      callbackId: cbid,
    ))
  )
  result = flecs_register_system_ex(
    name,
    includeComponents[0].unsafeAddr,
    uint32 includeComponents.len,
    if excludeComponents.len > 0: excludeComponents[0].unsafeAddr else: nil,
    uint32 excludeComponents.len,
    system_trampoline,
    cbid,
  )

proc addSystemEx*(name: string, includeComponents: openArray[Component], excludeComponents: openArray[Component], callback: SystemIterCallback): system_id_t =
  addSystemExIds(
    name,
    toComponentIds(includeComponents),
    toComponentIds(excludeComponents),
    callback,
  )

proc addSystemEx*(name: string, includeComponents: openArray[string], excludeComponents: openArray[string], callback: SystemIterCallback): system_id_t =
  addSystemExIds(name, toComponentIds(includeComponents), toComponentIds(excludeComponents), callback)

proc addSystemEx*(name: string, includeComponents: openArray[component_id_t], excludeComponents: openArray[component_id_t], callback: SystemIterCallback): system_id_t =
  addSystemExIds(name, includeComponents, excludeComponents, callback)
