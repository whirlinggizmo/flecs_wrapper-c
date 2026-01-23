# lib/flecs/flecs.nim
import std/tables
import std/macros
import std/os
import std/typetraits

# header files are in lib/flecs/flecs_wrapper/include
# source files are in lib/flecs/flecs_wrapper/src

# Create absolute paths to the flecs wrapper
# Note that source files are relative to the Nim file (this file),
# but linker paths are relative to the Nim project root (consumer).  
# So, we create absolute paths to the flecs wrapper from this file location
const thisDir = currentSourcePath().parentDir()
const flecsWrapperRoot = thisDir / ".." / ".."
const flecsWrapperIncludeDir = flecsWrapperRoot / "include"
const flecsWrapperSrcDir = flecsWrapperRoot / "src"
const flecsWrapperLibDir = flecsWrapperRoot / "lib"

{.passC: "-I" & flecsWrapperIncludeDir.}
{.passC: "-std=c99".}
{.passC: "-D_GNU_SOURCE".}

# build as a static library (libflecs_wrapper.a)
{.passL: "-static".}

when defined(FLECS_BUILD_SOURCE):
  # include the source directly vs.linking to a static lib 
  {.compile: flecsWrapperSrcDir / "flecs.c".}
  {.compile: flecsWrapperSrcDir / "flecs_wrapper.c".}
  {.compile: flecsWrapperSrcDir / "flecs_wrapper_world.c".}
  {.compile: flecsWrapperSrcDir / "flecs_wrapper_entity.c".}
  {.compile: flecsWrapperSrcDir / "flecs_wrapper_component.c".}
  {.compile: flecsWrapperSrcDir / "flecs_wrapper_components.c".}
  {.compile: flecsWrapperSrcDir / "flecs_wrapper_event.c".}
  {.compile: flecsWrapperSrcDir / "flecs_wrapper_system.c".}
  {.compile: flecsWrapperSrcDir / "systems" / "move_system.c".}
  {.compile: flecsWrapperSrcDir / "systems" / "destination_system.c".}
else:
  # include the static lib version (.a) of flecs instead of defaulting to the shared (.so)
  # see flecs_wrapper/Makefile
  {.passL: "-L" & flecsWrapperLibDir.}
  {.passL: "-lflecs_wrapper".}
  {.passL: "-lm".} # order matters, link math after flecs


{.push header: "flecs_wrapper_components.h".}
type
  entity_id_t* = uint32
  component_id_t* = uint32
  event_id_t* = uint32

  Position* {.importc, nodecl, bycopy.} = object
    x*, y*: cfloat

  Velocity* {.importc, nodecl, bycopy.} = object
    x*, y*: cfloat

  Destination* {.importc, nodecl, bycopy.} = object
    x*, y*, speed*: cfloat

{.pop.}

const
  ecsUnknownEvent*: uint32 = 0
  ecsOnAdd*: uint32 = 1
  ecsOnRemove*: uint32 = 2
  ecsOnSet*: uint32 = 3
  ecsOnDelete*: uint32 = 4
  ecsOnDeleteTarget*: uint32 = 5
  ecsOnTableCreate*: uint32 = 6
  ecsOnTableDelete*: uint32 = 7

# Low-level binding
proc c_flecs_component_create(
  name: cstring, size: uint32
): uint32 {.importc: "flecs_component_create", cdecl.}

proc flecs_component_create_tag*(name: cstring): uint32 {.importc.}

# High-level macro for registration
macro flecs_component_create*(T: typedesc): untyped =
  let typeName = repr(T)
  quote:
    c_flecs_component_create(`typeName`, cast[uint32](sizeof(`T`)))

proc flecs_component_get_id_by_name*(name: cstring): uint32 {.importc.}
proc flecs_component_is_tag*(component_id: uint32): bool {.importc.}
proc flecs_component_print_registry*() {.importc.}

proc flecs_entity_print_components*(entity_id: uint32) {.importc.}
proc flecs_entity_has_component*(entity_id, component_id: uint32): bool {.importc.}
proc flecs_entity_has_component_by_name*(
  entity_id: uint32, name: cstring
): bool {.importc.}

proc flecs_entity_add_component*(entity_id, component_id: uint32): bool {.importc.}
proc flecs_entity_add_component_by_name*(
  entity_id: uint32, name: cstring
): bool {.importc.}

proc flecs_entity_remove_component*(entity_id, component_id: uint32): bool {.importc.}
proc flecs_entity_remove_component_by_name*(
  entity_id: uint32, name: cstring
): bool {.importc.}

proc flecs_entity_get_component*(entity_id, component_id: uint32): pointer {.importc.}
proc flecs_entity_set_component*(
  entity_id, component_id: uint32, component_pointer: pointer
): bool {.importc.}

proc flecs_entity_mark_component*(entity_id: uint32, component_id: uint32) {.importc.}

proc flecs_entity_create*(name: cstring): uint32 {.importc.}
proc flecs_entity_destroy*(entity_id: uint32): bool {.importc.}

type FlecsObserverCallback* = proc(
  entity_ids: ptr entity_id_t,
  entity_count: uint32,
  columns: ptr pointer,
  column_component_ids: ptr component_id_t,
  column_sizes: ptr uint32,
  column_count: uint32,
  event_id: event_id_t,
  component_id: component_id_t,
  callback_id: uint32,
) {.cdecl.}

proc flecs_register_observer*(
  component_ids: ptr uint32,
  num_components: uint32,
  event_ids: ptr uint32,
  num_events: uint32,
  callback: FlecsObserverCallback,
  callback_id: uint32,
): uint32 {.importc.}

proc flecs_register_observer_ex*(
  include_component_ids: ptr uint32,
  num_include_components: uint32,
  exclude_component_ids: ptr uint32,
  num_exclude_components: uint32,
  event_ids: ptr uint32,
  num_events: uint32,
  callback: FlecsObserverCallback,
  callback_id: uint32,
): uint32 {.importc.}

proc flecs_init*() {.importc.}
proc flecs_progress*(delta_time: float32) {.importc.}
proc flecs_fini*() {.importc.}
proc flecs_set_threads*(threads: int32) {.importc.}
proc flecs_version*(): cstring {.importc.}

# Observer callback trampoline
type ObserverCallback = proc(
  entities: ptr UncheckedArray[entity_id_t],
  columns: seq[pointer],
  columnComponentIds: seq[component_id_t],
  columnSizes: seq[uint32],
  count: uint32,
  event: event_id_t,
  component: component_id_t,
) {.gcsafe.}

# Internal state
var
  nextObserverCallbackId {.threadvar.}: uint32
  observerCallbackMap {.threadvar.}: Table[uint32, ObserverCallback]
  observerCbInited {.threadvar.}: bool

proc ensureObserverCbInit() {.inline.} =
  if not observerCbInited:
    observerCbInited = true
    nextObserverCallbackId = 1'u32 # Reserve 0 for invalid ID
    observerCallbackMap = initTable[uint32, ObserverCallback]()

# Register a callback and return its ID
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

# Called from C — dispatches to registered Nim callbacks
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

# utility to unregister
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

type FlecsSystemCallback* = proc(
  entity_ids: ptr entity_id_t,
  entity_count: uint32,
  columns: ptr pointer,
  column_component_ids: ptr component_id_t,
  column_sizes: ptr uint32,
  column_count: uint32,
  delta_time: float32,
  callback_id: uint32,
) {.cdecl.}

proc flecs_register_system(
  name: cstring,
  component_ids: ptr uint32,
  num_components: uint32,
  callback: FlecsSystemCallback,
  callback_id: uint32,
): uint32 {.importc.}

proc flecs_register_system_ex(
  name: cstring,
  include_component_ids: ptr uint32,
  num_include_components: uint32,
  exclude_component_ids: ptr uint32,
  num_exclude_components: uint32,
  callback: FlecsSystemCallback,
  callback_id: uint32,
): uint32 {.importc.}

# System callback trampoline

type SystemCallback = proc(
  entities: ptr UncheckedArray[entity_id_t],
  columns: seq[pointer],
  columnComponentIds: seq[component_id_t],
  columnSizes: seq[uint32],
  count: uint32,
  delta_time: float32,
) {.gcsafe.}

# Internal state
var
  nextSystemCallbackId {.threadvar.}: uint32
  systemCallbackMap {.threadvar.}: Table[uint32, SystemCallback]
  systemCbInited {.threadvar.}: bool

proc ensureSystemCbInit() {.inline.} =
  if not systemCbInited:
    systemCbInited = true
    nextSystemCallbackId = 1'u32 # Reserve 0 for invalid ID
    systemCallbackMap = initTable[uint32, SystemCallback]()

# Register a callback and return its ID
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

# Called from C — dispatches to registered Nim callbacks
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

# utility to unregister system
# NOTE:  this only unregisters the Nim callback, not the flecs system itself
# TODO: add flecs_unregister_system to flecs_wrapper and call it here
# We'll need some way to track the callbacks AND flecs system IDs together
# so we can clean up both properly.
proc flecs_remove_system*(id: uint32) =
  ensureSystemCbInit()
  if systemCallbackMap.hasKey(id):
    systemCallbackMap.del(id)
    echo "✅ Callback with id ", id, " unregistered."
  else:
    echo "⚠️ Tried to unregister missing callback id ", id

proc flecs_add_system*(
    name: string, components: openArray[uint32], callback: SystemCallback
): uint32 =
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
  # Note:  We are actually returning the callback ID, not the system ID
  # TODO: change this to return both IDs or track them together some other way
  # so we can properly unregister both later.
  # See note on flecs_remove_system above.
  return system_id

proc flecs_add_task*(
    name: string, callback: SystemCallback
): uint32 =
  ensureSystemCbInit()
  if callback.isNil:
    echo "⚠️ Warning: tried to register nil callback"
    return

  let cbid = register_system_callback(callback)
  let task_id = flecs_register_system(
    name, nil, 0, system_trampoline, cbid
  )
  return task_id

# High-level Nim wrappers (Lua parity)

type
  Component* = object
    name*: string
    id*: component_id_t
    size*: uint32

  Entity* = object
    id*: entity_id_t

  SystemIter* = object
    entityIds*: ptr UncheckedArray[entity_id_t]
    count*: uint32
    columns*: seq[pointer]
    columnComponentIds*: seq[component_id_t]
    columnSizes*: seq[uint32]
    dt*: float32
    callbackId*: uint32

  ObserverIter* = object
    entityIds*: ptr UncheckedArray[entity_id_t]
    count*: uint32
    columns*: seq[pointer]
    columnComponentIds*: seq[component_id_t]
    columnSizes*: seq[uint32]
    eventId*: event_id_t
    componentId*: component_id_t
    callbackId*: uint32

  SystemIterCallback* = proc(it: SystemIter) {.gcsafe, closure.}
  ObserverIterCallback* = proc(it: ObserverIter) {.gcsafe, closure.}

macro typeName*(T: typedesc): untyped =
  newLit(repr(T))

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
  let id = c_flecs_component_create(compName, cast[uint32](sizeof(T)))
  if id == 0:
    raise newException(ValueError, "component_create failed for " & compName)
  return Component(name: compName, id: id, size: cast[uint32](sizeof(T)))

proc createTag*(name: string): Component =
  let id = flecs_component_create_tag(name)
  if id == 0:
    raise newException(ValueError, "component_create_tag failed for " & name)
  return Component(name: name, id: id, size: 0)

proc isTag*(comp: Component): bool =
  flecs_component_is_tag(comp.id)

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

proc entity*(it: SystemIter, i: int): entity_id_t =
  if i < 0 or i >= int(it.count):
    raise newException(IndexDefect, "entity index out of bounds")
  it.entityIds[i]

proc entity*(it: ObserverIter, i: int): entity_id_t =
  if i < 0 or i >= int(it.count):
    raise newException(IndexDefect, "entity index out of bounds")
  it.entityIds[i]

proc colIndex*(it: SystemIter, compId: component_id_t): int =
  for i in 0 ..< it.columnComponentIds.len:
    if it.columnComponentIds[i] == compId:
      return i
  return -1

proc colIndex*(it: ObserverIter, compId: component_id_t): int =
  for i in 0 ..< it.columnComponentIds.len:
    if it.columnComponentIds[i] == compId:
      return i
  return -1

proc colPtr*[T](it: SystemIter, compId: component_id_t): ptr UncheckedArray[T] =
  let idx = it.colIndex(compId)
  if idx < 0:
    return nil
  cast[ptr UncheckedArray[T]](it.columns[idx])

proc colPtr*[T](it: ObserverIter, compId: component_id_t): ptr UncheckedArray[T] =
  let idx = it.colIndex(compId)
  if idx < 0:
    return nil
  cast[ptr UncheckedArray[T]](it.columns[idx])

proc colPtr*[T](it: SystemIter, comp: Component): ptr UncheckedArray[T] =
  colPtr[T](it, comp.id)

proc colPtr*[T](it: ObserverIter, comp: Component): ptr UncheckedArray[T] =
  colPtr[T](it, comp.id)

proc col*[T](it: SystemIter, compId: component_id_t, i: int): ptr T =
  let ptrs = colPtr[T](it, compId)
  if ptrs.isNil:
    return nil
  if i < 0 or i >= int(it.count):
    raise newException(IndexDefect, "column index out of bounds")
  addr ptrs[i]

proc col*[T](it: ObserverIter, compId: component_id_t, i: int): ptr T =
  let ptrs = colPtr[T](it, compId)
  if ptrs.isNil:
    return nil
  if i < 0 or i >= int(it.count):
    raise newException(IndexDefect, "column index out of bounds")
  addr ptrs[i]

proc col*[T](it: SystemIter, comp: Component, i: int): ptr T =
  col[T](it, comp.id, i)

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

proc toComponentIds(components: openArray[component_id_t]): seq[component_id_t] =
  @components

proc validateEventIds(events: openArray[event_id_t]) =
  for ev in events:
    if ev < 1:
      raise newException(ValueError, "Invalid event id: " & $ev)

proc addSystemIds(name: string, components: openArray[component_id_t], callback: SystemIterCallback): uint32 =
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

proc addSystem*(name: string, components: openArray[Component], callback: SystemIterCallback): uint32 =
  addSystemIds(name, toComponentIds(components), callback)

proc addSystem*(name: string, components: openArray[string], callback: SystemIterCallback): uint32 =
  addSystemIds(name, toComponentIds(components), callback)

proc addSystem*(name: string, components: openArray[component_id_t], callback: SystemIterCallback): uint32 =
  addSystemIds(name, components, callback)

proc addSystemExIds(name: string, includeComponents: openArray[component_id_t], excludeComponents: openArray[component_id_t], callback: SystemIterCallback): uint32 =
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

proc addSystemEx*(name: string, includeComponents: openArray[Component], excludeComponents: openArray[Component], callback: SystemIterCallback): uint32 =
  addSystemExIds(
    name,
    toComponentIds(includeComponents),
    toComponentIds(excludeComponents),
    callback,
  )

proc addSystemEx*(name: string, includeComponents: openArray[string], excludeComponents: openArray[string], callback: SystemIterCallback): uint32 =
  addSystemExIds(name, toComponentIds(includeComponents), toComponentIds(excludeComponents), callback)

proc addSystemEx*(name: string, includeComponents: openArray[component_id_t], excludeComponents: openArray[component_id_t], callback: SystemIterCallback): uint32 =
  addSystemExIds(name, includeComponents, excludeComponents, callback)

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
