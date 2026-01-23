import std/tables

import ./flecs
import ./component_wrapper

type
  ObserverIter* = object
    entityIds*: ptr UncheckedArray[entity_id_t]
    count*: uint32
    columns*: seq[pointer]
    columnComponentIds*: seq[component_id_t]
    columnSizes*: seq[uint32]
    eventId*: event_id_t
    componentId*: component_id_t
    callbackId*: uint32

  ObserverIterCallback* = proc(it: ObserverIter) {.gcsafe, closure.}

type ObserverCallback = proc(
  entities: ptr UncheckedArray[entity_id_t],
  columns: seq[pointer],
  columnComponentIds: seq[component_id_t],
  columnSizes: seq[uint32],
  count: uint32,
  event: event_id_t,
  component: component_id_t,
) {.gcsafe.}

var
  nextObserverCallbackId {.threadvar.}: uint32
  observerCallbackMap {.threadvar.}: Table[uint32, ObserverCallback]
  observerCbInited {.threadvar.}: bool

proc ensureObserverCbInit() {.inline.} =
  if not observerCbInited:
    observerCbInited = true
    nextObserverCallbackId = 1'u32 # Reserve 0 for invalid ID
    observerCallbackMap = initTable[uint32, ObserverCallback]()

proc register_observer_callback(cb: ObserverCallback, id: uint32 = 0'u32): uint32 =
  ensureObserverCbInit()
  if cb.isNil:
    echo "⚠️ Warning: tried to register nil callback"
    return 0

  var realId = id
  if realId == 0:
    realId = nextObserverCallbackId
    inc nextObserverCallbackId

  if observerCallbackMap.hasKey(realId):
    echo "⚠️ Warning: callback already registered for id ", realId
    return 0

  observerCallbackMap[realId] = cb
  return realId

proc observer_trampoline(
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
  ensureObserverCbInit()
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

  if observerCallbackMap.hasKey(callback_id):
    observerCallbackMap[callback_id](
      entityArr,
      columnPtrs,
      columnComponentIds,
      columnSizesSeq,
      entity_count,
      event_id,
      component_id,
    )
  else:
    echo "⚠️ No callback registered for id ", callback_id

proc flecs_remove_observer*(id: uint32) =
  ensureObserverCbInit()
  if observerCallbackMap.hasKey(id):
    observerCallbackMap.del(id)
    echo "✅ Callback with id ", id, " unregistered."
  else:
    echo "⚠️ Tried to unregister missing callback id ", id

proc flecs_add_observer*(
    components: openArray[uint32], events: openArray[uint32], callback: ObserverCallback
): uint32 =
  ensureObserverCbInit()
  if callback.isNil:
    echo "⚠️ Warning: tried to register nil callback"
    return

  if components.len == 0 or events.len == 0:
    echo "⚠️ Warning: tried to register observer with no components or events"
    return

  let id = register_observer_callback(callback)
  discard flecs_register_observer(
    components[0].addr,
    uint32 components.len,
    events[0].addr,
    uint32 events.len,
    observer_trampoline,
    id,
  )
  return id

proc entity*(it: ObserverIter, i: int): entity_id_t =
  if i < 0 or i >= int(it.count):
    raise newException(IndexDefect, "entity index out of bounds")
  it.entityIds[i]

proc colIndex(it: ObserverIter, compId: component_id_t): int =
  for i in 0 ..< it.columnComponentIds.len:
    if it.columnComponentIds[i] == compId:
      return i
  return -1

proc colPtr*[T](it: ObserverIter, compId: component_id_t): ptr UncheckedArray[T] =
  let idx = it.colIndex(compId)
  if idx < 0:
    return nil
  cast[ptr UncheckedArray[T]](it.columns[idx])

proc colPtr*[T](it: ObserverIter, comp: Component): ptr UncheckedArray[T] =
  colPtr[T](it, comp.id)

proc col*[T](it: ObserverIter, compId: component_id_t, i: int): ptr T =
  let ptrs = colPtr[T](it, compId)
  if ptrs.isNil:
    return nil
  if i < 0 or i >= int(it.count):
    raise newException(IndexDefect, "column index out of bounds")
  addr ptrs[i]

proc col*[T](it: ObserverIter, comp: Component, i: int): ptr T =
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

proc validateEventIds(events: openArray[event_id_t]) =
  for ev in events:
    if ev < 1:
      raise newException(ValueError, "Invalid event id: " & $ev)

proc addObserverIds(components: openArray[component_id_t], events: openArray[event_id_t], callback: ObserverIterCallback): uint32 =
  if components.len == 0:
    raise newException(ValueError, "Observer must include at least one component")
  if events.len == 0:
    raise newException(ValueError, "Observer must include at least one event")
  if callback.isNil:
    raise newException(ValueError, "Observer callback is nil")
  validateEventIds(events)
  var cbid: uint32
  cbid = register_observer_callback(proc(
    entities: ptr UncheckedArray[entity_id_t],
    columns: seq[pointer],
    columnComponentIds: seq[component_id_t],
    columnSizes: seq[uint32],
    count: uint32,
    event: event_id_t,
    component: component_id_t,
  ) {.gcsafe.} =
    callback(ObserverIter(
      entityIds: entities,
      count: count,
      columns: columns,
      columnComponentIds: columnComponentIds,
      columnSizes: columnSizes,
      eventId: event,
      componentId: component,
      callbackId: cbid,
    ))
  )
  result = flecs_register_observer(
    components[0].unsafeAddr,
    uint32 components.len,
    cast[ptr uint32](unsafeAddr events[0]),
    uint32 events.len,
    observer_trampoline,
    cbid,
  )

proc addObserver*(components: openArray[Component], events: openArray[event_id_t], callback: ObserverIterCallback): uint32 =
  addObserverIds(toComponentIds(components), events, callback)

proc addObserver*(components: openArray[string], events: openArray[event_id_t], callback: ObserverIterCallback): uint32 =
  addObserverIds(toComponentIds(components), events, callback)

proc addObserver*(components: openArray[component_id_t], events: openArray[event_id_t], callback: ObserverIterCallback): uint32 =
  addObserverIds(components, events, callback)

proc addObserverExIds(includeComponents: openArray[component_id_t], excludeComponents: openArray[component_id_t], events: openArray[event_id_t], callback: ObserverIterCallback): uint32 =
  if includeComponents.len == 0:
    raise newException(ValueError, "Observer must include at least one component")
  if events.len == 0:
    raise newException(ValueError, "Observer must include at least one event")
  if callback.isNil:
    raise newException(ValueError, "Observer callback is nil")
  validateEventIds(events)
  var cbid: uint32
  cbid = register_observer_callback(proc(
    entities: ptr UncheckedArray[entity_id_t],
    columns: seq[pointer],
    columnComponentIds: seq[component_id_t],
    columnSizes: seq[uint32],
    count: uint32,
    event: event_id_t,
    component: component_id_t,
  ) {.gcsafe.} =
    callback(ObserverIter(
      entityIds: entities,
      count: count,
      columns: columns,
      columnComponentIds: columnComponentIds,
      columnSizes: columnSizes,
      eventId: event,
      componentId: component,
      callbackId: cbid,
    ))
  )
  result = flecs_register_observer_ex(
    includeComponents[0].unsafeAddr,
    uint32 includeComponents.len,
    if excludeComponents.len > 0: excludeComponents[0].unsafeAddr else: nil,
    uint32 excludeComponents.len,
    cast[ptr uint32](unsafeAddr events[0]),
    uint32 events.len,
    observer_trampoline,
    cbid,
  )

proc addObserverEx*(includeComponents: openArray[Component], excludeComponents: openArray[Component], events: openArray[event_id_t], callback: ObserverIterCallback): uint32 =
  addObserverExIds(
    toComponentIds(includeComponents),
    toComponentIds(excludeComponents),
    events,
    callback,
  )

proc addObserverEx*(includeComponents: openArray[string], excludeComponents: openArray[string], events: openArray[event_id_t], callback: ObserverIterCallback): uint32 =
  addObserverExIds(toComponentIds(includeComponents), toComponentIds(excludeComponents), events, callback)

proc addObserverEx*(includeComponents: openArray[component_id_t], excludeComponents: openArray[component_id_t], events: openArray[event_id_t], callback: ObserverIterCallback): uint32 =
  addObserverExIds(includeComponents, excludeComponents, events, callback)
