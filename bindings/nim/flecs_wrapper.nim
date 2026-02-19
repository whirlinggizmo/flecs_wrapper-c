# lib/flecs/flecs.nim
import std/os

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

# Do not force full static system linking in GDExtension builds.
# We only want flecs_wrapper code linked into the extension binary.

when defined(FLECS_BUILD_SOURCE):
  # include the source directly vs.linking to a static lib 
  {.compile: flecsWrapperSrcDir / "flecs.c".}
  {.compile: flecsWrapperSrcDir / "flecs_wrapper.c".}
  {.compile: flecsWrapperSrcDir / "flecs_wrapper_world.c".}
  {.compile: flecsWrapperSrcDir / "flecs_wrapper_entity.c".}
  {.compile: flecsWrapperSrcDir / "flecs_wrapper_component.c".}
  {.compile: flecsWrapperSrcDir / "flecs_wrapper_components.c".}
  {.compile: flecsWrapperSrcDir / "flecs_wrapper_id.c".}
  {.compile: flecsWrapperSrcDir / "flecs_wrapper_pair.c".}
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
  system_id_t* = uint32
  observer_id_t* = uint32
  pair_id_t* = uint32

  Position* {.importc, nodecl, bycopy.} = object
    x*, y*, z*: cfloat

  Velocity* {.importc, nodecl, bycopy.} = object
    x*, y*, z*: cfloat

  Destination* {.importc, nodecl, bycopy.} = object
    x*, y*, z*, speed*: cfloat

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
proc c_flecs_component_create*(
  name: cstring, size: uint32
): uint32 {.importc: "flecs_component_create", cdecl.}

proc flecs_component_create_tag*(name: cstring): uint32 {.importc.}

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

proc flecs_pair_register*(relation_component_id: component_id_t, object_entity_id: entity_id_t): pair_id_t {.importc.}
proc flecs_pair_register_entity*(relation_entity_id: entity_id_t, object_entity_id: entity_id_t): pair_id_t {.importc.}
proc flecs_pair_register_by_name*(relation_name: cstring, object_name: cstring): pair_id_t {.importc.}
proc flecs_pair_unregister*(pair_id: pair_id_t): bool {.importc.}

proc flecs_entity_add_pair*(entity_id: entity_id_t, pair_id: pair_id_t): bool {.importc.}
proc flecs_entity_remove_pair*(entity_id: entity_id_t, pair_id: pair_id_t): bool {.importc.}
proc flecs_entity_has_pair*(entity_id: entity_id_t, pair_id: pair_id_t): bool {.importc.}
proc flecs_entity_set_pair*(entity_id: entity_id_t, pair_id: pair_id_t, pair_pointer: pointer): bool {.importc.}
proc flecs_entity_get_pair*(entity_id: entity_id_t, pair_id: pair_id_t): pointer {.importc.}

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
): observer_id_t {.importc.}

proc flecs_register_observer_ex*(
  include_component_ids: ptr uint32,
  num_include_components: uint32,
  exclude_component_ids: ptr uint32,
  num_exclude_components: uint32,
  event_ids: ptr uint32,
  num_events: uint32,
  callback: FlecsObserverCallback,
  callback_id: uint32,
): observer_id_t {.importc.}

proc flecs_unregister_observer*(observer_id: observer_id_t): bool {.importc.}

proc flecs_init*() {.importc.}
proc flecs_progress*(delta_time: float32) {.importc.}
proc flecs_fini*() {.importc.}
proc flecs_set_threads*(threads: int32) {.importc.}
proc flecs_version*(): cstring {.importc.}

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

proc flecs_register_system*(
  name: cstring,
  component_ids: ptr uint32,
  num_components: uint32,
  callback: FlecsSystemCallback,
  callback_id: uint32,
): system_id_t {.importc.}

proc flecs_register_system_ex*(
  name: cstring,
  include_component_ids: ptr uint32,
  num_include_components: uint32,
  exclude_component_ids: ptr uint32,
  num_exclude_components: uint32,
  callback: FlecsSystemCallback,
  callback_id: uint32,
): system_id_t {.importc.}

proc flecs_unregister_system*(system_id: system_id_t): bool {.importc.}
