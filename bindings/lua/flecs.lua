-- helpers

local function my_dir()
    local src = debug.getinfo(1, "S").source
    local path = src:sub(1, 1) == "@" and src:sub(2) or "app"
    return path:match("^(.*[/\\])") or "./"
end

local function normalize_path(path)
    if not path or path == "" then
        return ""
    end

    local original = path
    path = path:gsub("\\", "/")
    path = path:gsub("/+", "/")

    local prefix = ""
    if path:match("^//") then
        prefix = "//"
        path = path:sub(3)
    else
        local drive = path:match("^(%a:)/")
        if drive then
            prefix = drive .. "/"
            path = path:sub(#prefix + 1)
        elseif path:sub(1, 1) == "/" then
            prefix = "/"
            path = path:sub(2)
        end
    end

    local parts = {}
    for part in path:gmatch("[^/]+") do
        if part == "." then
            -- skip
        elseif part == ".." then
            if #parts > 0 and parts[#parts] ~= ".." then
                table.remove(parts)
            elseif prefix == "" then
                parts[#parts + 1] = part
            end
        else
            parts[#parts + 1] = part
        end
    end

    local normalized = prefix .. table.concat(parts, "/")
    local wants_trailing = original:match("[/\\]$") ~= nil
    if wants_trailing and normalized ~= "" and normalized:sub(-1) ~= "/" then
        normalized = normalized .. "/"
    end
    if normalized == "" then
        return prefix ~= "" and prefix or "."
    end
    return normalized
end




-- Minimal LuaJIT FFI wrapper for flecs_wrapper.
local ffi = require("ffi")

ffi.cdef[[
typedef unsigned char uint8_t;
typedef signed int int32_t;
typedef unsigned int uint32_t;

typedef uint32_t entity_id_t;
typedef uint32_t component_id_t;
typedef uint32_t event_id_t;

// known components
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

typedef void (*ObserverCallback)(
  const entity_id_t *entity_ids,
  uint32_t entity_count,
  void **columns,
  const component_id_t *column_component_ids,
  const uint32_t *column_sizes,
  uint32_t column_count,
  event_id_t event_id,
  component_id_t component_id,
  uint32_t callback_id
);

void flecs_init(void);
void flecs_progress(float delta_time);
void flecs_fini(void);
void flecs_set_threads(int32_t threads);

const char *flecs_version(void);

component_id_t flecs_component_get_id_by_name(const char *name);
int flecs_component_is_tag(component_id_t component_id);
void flecs_component_print_registry(void);
component_id_t flecs_component_create(const char *name, uint32_t size);
component_id_t flecs_component_create_tag(const char *name);

entity_id_t flecs_entity_create(const char *name);
int flecs_entity_destroy(entity_id_t entity_id);
void flecs_entity_print_components(entity_id_t entity_id);
int flecs_entity_has_component(entity_id_t entity_id, component_id_t component_id);
int flecs_entity_has_component_by_name(entity_id_t entity_id, const char *component_name);
int flecs_entity_add_component(entity_id_t entity_id, component_id_t component_id);
int flecs_entity_add_component_by_name(entity_id_t entity_id, const char *component_name);
int flecs_entity_remove_component(entity_id_t entity_id, component_id_t component_id);
int flecs_entity_remove_component_by_name(entity_id_t entity_id, const char *component_name);
int flecs_entity_set_component(entity_id_t entity_id, component_id_t component_id, const void *component_data_ptr);
const void *flecs_entity_get_component(entity_id_t entity_id, component_id_t component_id);
void flecs_entity_mark_component(entity_id_t entity_id, component_id_t component_id);

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

int flecs_register_observer(
  component_id_t *component_ids,
  uint32_t num_components,
  event_id_t *event_ids,
  uint32_t num_events,
  ObserverCallback callback,
  uint32_t callback_id
);
]]

local M = {}
M.ffi = ffi
M.events = {
  ON_ADD = 1,
  ON_REMOVE = 2,
  ON_SET = 3,
  ON_DELETE = 4,
  ON_DELETE_TARGET = 5,
  ON_TABLE_CREATE = 6,
  ON_TABLE_DELETE = 7,
}
M.types = {
  Position = ffi.typeof("Position"),
  Velocity = ffi.typeof("Velocity"),
  Destination = ffi.typeof("Destination"),
  EntityId = ffi.typeof("EntityId"),
}

local function load_lib()
  local lib_path = my_dir() .. "../../libflecs_wrapper.so"
  lib_path = normalize_path(lib_path)
  local ok, lib = pcall(ffi.load, lib_path)
  if ok then
    print("Loaded flecs_wrapper.so from " .. lib_path)
    return lib
  end
  local lib_path_deps = my_dir() .. "../../lib/libflecs_wrapper.so"
  ok, lib = pcall(ffi.load, lib_path_deps)
  if ok then
    print("Loaded flecs_wrapper.so from " .. lib_path_deps)
    return lib
  end
  error("Failed to load flecs_wrapper (tried " .. lib_path .. " and " .. lib_path_deps .. ")")
end

local C = load_lib()

M._C = C
M._callbacks = {}
M._nextCallbackId = 1

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

function M.version()
  local v = C.flecs_version()
  if v == nil then
    return nil
  end
  return ffi.string(v)
end

function M.component_is_tag(component_id)
  return C.flecs_component_is_tag(component_id) ~= 0
end

function M.component_print_registry()
  C.flecs_component_print_registry()
end

function M.component_create(name, size)
  return C.flecs_component_create(name, size)
end

function M.component_create_tag(name)
  return C.flecs_component_create_tag(name)
end

function M.entity_create(name)
  return C.flecs_entity_create(name)
end

function M.entity_destroy(entity_id)
  return C.flecs_entity_destroy(entity_id)
end

function M.entity_print_components(entity_id)
  C.flecs_entity_print_components(entity_id)
end

function M.entity_has_component(entity_id, component_id)
  return C.flecs_entity_has_component(entity_id, component_id) ~= 0
end

function M.entity_has_component_by_name(entity_id, component_name)
  return C.flecs_entity_has_component_by_name(entity_id, component_name) ~= 0
end

function M.entity_add_component(entity_id, component_id)
  return C.flecs_entity_add_component(entity_id, component_id)
end

function M.entity_add_component_by_name(entity_id, component_name)
  return C.flecs_entity_add_component_by_name(entity_id, component_name) ~= 0
end

function M.entity_remove_component(entity_id, component_id)
  return C.flecs_entity_remove_component(entity_id, component_id)
end

function M.entity_remove_component_by_name(entity_id, component_name)
  return C.flecs_entity_remove_component_by_name(entity_id, component_name) ~= 0
end

function M.entity_set_component(entity_id, component_id, data_ptr)
  return C.flecs_entity_set_component(entity_id, component_id, data_ptr)
end

function M.entity_mark_component(entity_id, component_id)
  C.flecs_entity_mark_component(entity_id, component_id)
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

local function event_ids_from_list(event_ids)
  local count = #event_ids
  local ids = ffi.new("event_id_t[?]", count)
  for i = 1, count do
    local eid = tonumber(event_ids[i])
    if not eid or eid < 1 then
      error("Invalid event id: " .. tostring(event_ids[i]))
    end
    ids[i - 1] = eid
  end
  return ids, count
end

function M.register_observer(component_names, event_ids, lua_callback, callback_id)
  local component_ids, component_count = ids_from_names(component_names)
  local ev_ids, ev_count = event_ids_from_list(event_ids)

  local id = tonumber(callback_id) or 0
  if id == 0 then
    id = M._nextCallbackId
    M._nextCallbackId = M._nextCallbackId + 1
  end

  local function safe_callback(...)
    local ok, err = pcall(lua_callback, ...)
    if not ok then
      io.stderr:write("[flecs_wrapper] Lua observer callback error: " .. tostring(err) .. "\n")
    end
  end
  local cb = ffi.cast("ObserverCallback", safe_callback)
  local ok = C.flecs_register_observer(component_ids, component_count, ev_ids, ev_count, cb, id)
  if not ok then
    error("flecs_register_observer failed")
  end
  M._callbacks[id] = {cb = cb, safe = safe_callback, original = lua_callback}
  return id
end

return M
