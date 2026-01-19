-- Minimal LuaJIT FFI wrapper for flecs_wrapper.
local ffi = require("ffi")

ffi.cdef[[
typedef uint32_t entity_id_t;
typedef uint32_t component_id_t;

typedef struct Position { float x; float y; } Position;
typedef struct Velocity { float x; float y; } Velocity;
typedef struct Destination { float x; float y; float speed; } Destination;
typedef struct EntityId { uint32_t value; } EntityId;

typedef void (*SystemCallback)(
  const entity_id_t *entity_ids,
  uint32_t entity_count,
  void **columns,
  const component_id_t *column_component_ids,
  const uint32_t *column_sizes,
  uint32_t column_count,
  float delta_time,
  uint32_t callback_id
);

void flecs_init(void);
void flecs_progress(float delta_time);
void flecs_fini(void);
void flecs_set_threads(int32_t threads);

component_id_t flecs_component_get_id_by_name(const char *name);
component_id_t flecs_component_create(const char *name, uint32_t size);

entity_id_t flecs_entity_create(const char *name);
bool flecs_entity_destroy(entity_id_t entity_id);
bool flecs_entity_add_component(entity_id_t entity_id, component_id_t component_id);
bool flecs_entity_remove_component(entity_id_t entity_id, component_id_t component_id);
bool flecs_entity_set_component(entity_id_t entity_id, component_id_t component_id, const void *component_data_ptr);
const void *flecs_entity_get_component(entity_id_t entity_id, component_id_t component_id);

uint32_t flecs_register_system(
  const char *name,
  component_id_t *component_ids,
  uint32_t num_components,
  SystemCallback callback,
  uint32_t callback_id
);
uint32_t flecs_register_system_ex(
  const char *name,
  component_id_t *include_component_ids,
  uint32_t num_include_components,
  component_id_t *exclude_component_ids,
  uint32_t num_exclude_components,
  SystemCallback callback,
  uint32_t callback_id
);
]]

local M = {}
M.ffi = ffi
M.types = {
  Position = ffi.typeof("Position"),
  Velocity = ffi.typeof("Velocity"),
  Destination = ffi.typeof("Destination"),
  EntityId = ffi.typeof("EntityId"),
}

local function load_lib()
  local path = require("flecs_wrapper.bindings.lua.path")
  local lib_path = path.path_dir() .. "../../lib/libflecs_wrapper.so"
  lib_path = path.normalize_path(lib_path)
  local ok, lib = pcall(ffi.load, lib_path)
  if ok then
    print("Loaded flecs_wrapper.so from " .. lib_path)
    return lib
  end
  ok, lib = pcall(ffi.load, "flecs_wrapper")
  if ok then
    print("Loaded flecs_wrapper.so from " .. lib_path)
    return lib
  end
  error("Failed to load flecs_wrapper (tried " .. lib_path .. " and flecs_wrapper)")
end

local C = load_lib()

M._C = C
M._callbacks = {}

function M.init()
  C.flecs_init()
end

function M.progress(delta_time)
  C.flecs_progress(delta_time or 0)
end

function M.fini()
  C.flecs_fini()
end

function M.set_threads(threads)
  C.flecs_set_threads(threads or 0)
end

function M.new(ctype, init)
  return ffi.new(ctype, init)
end

function M.component_id(name)
  return C.flecs_component_get_id_by_name(name)
end

function M.component_create(name, size)
  return C.flecs_component_create(name, size)
end

function M.entity_create(name)
  return C.flecs_entity_create(name)
end

function M.entity_destroy(entity_id)
  return C.flecs_entity_destroy(entity_id)
end

function M.entity_add_component(entity_id, component_id)
  return C.flecs_entity_add_component(entity_id, component_id)
end

function M.entity_remove_component(entity_id, component_id)
  return C.flecs_entity_remove_component(entity_id, component_id)
end

function M.entity_set_component(entity_id, component_id, data_ptr)
  return C.flecs_entity_set_component(entity_id, component_id, data_ptr)
end

function M.entity_get_component(entity_id, component_id, ctype)
  local ptr = C.flecs_entity_get_component(entity_id, component_id)
  if ptr == nil then
    return nil
  end
  if ctype then
    return ffi.cast(ctype, ptr)
  end
  return ptr
end

local function ids_from_names(component_names)
  local count = #component_names
  local ids = ffi.new("component_id_t[?]", count)
  for i = 1, count do
    local id = C.flecs_component_get_id_by_name(component_names[i])
    if id == 0 then
      error("Unknown component name: " .. tostring(component_names[i]))
    end
    ids[i - 1] = id
  end
  return ids, count
end

function M.register_system(name, component_names, lua_callback, callback_id)
  local ids, count = ids_from_names(component_names)
  local function safe_callback(...)
    local ok, err = pcall(lua_callback, ...)
    if not ok then
      io.stderr:write("[flecs_wrapper] Lua system callback error: " .. tostring(err) .. "\n")
    end
  end
  local cb = ffi.cast("SystemCallback", safe_callback)
  local sys_id = C.flecs_register_system(name, ids, count, cb, callback_id or 0)
  if sys_id == 0 then
    error("flecs_register_system failed for " .. tostring(name))
  end
  M._callbacks[sys_id] = {cb = cb, safe = safe_callback, original = lua_callback}
  return sys_id
end

function M.register_system_ex(name, include_names, exclude_names, lua_callback, callback_id)
  local include_ids, include_count = ids_from_names(include_names)
  local exclude_ids, exclude_count = ids_from_names(exclude_names or {})
  local function safe_callback(...)
    local ok, err = pcall(lua_callback, ...)
    if not ok then
      io.stderr:write("[flecs_wrapper] Lua system callback error: " .. tostring(err) .. "\n")
    end
  end
  local cb = ffi.cast("SystemCallback", safe_callback)
  local sys_id = C.flecs_register_system_ex(
    name,
    include_ids,
    include_count,
    exclude_ids,
    exclude_count,
    cb,
    callback_id or 0
  )
  if sys_id == 0 then
    error("flecs_register_system_ex failed for " .. tostring(name))
  end
  M._callbacks[sys_id] = {cb = cb, safe = safe_callback, original = lua_callback}
  return sys_id
end

return M
