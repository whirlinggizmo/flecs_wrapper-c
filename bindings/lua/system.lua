local ecs = require("flecs_wrapper.bindings.lua.flecs_wrapper")
local component = require("flecs_wrapper.bindings.lua.component")
local ffi = ecs.ffi

local M = {}

local Iter = {}
Iter.__index = Iter

local function resolve_component(comp)
  if type(comp) == "string" then
    local obj = component.get(comp)
    if obj then
      return obj
    end
    local id = ecs.component_id(comp)
    if id == 0 then
      error("Unknown component name: " .. tostring(comp))
    end
    return {name = comp, id = id}
  end
  if type(comp) == "table" and comp.id then
    return comp
  end
  error("component must be a name or component object")
end

local function normalize_component_names(list)
  local names = {}
  for i = 1, #list do
    local comp = list[i]
    if type(comp) == "string" then
      names[i] = comp
    elseif type(comp) == "table" and comp.name then
      names[i] = comp.name
    else
      error("component must be a name or component object")
    end
  end
  return names
end

function Iter:entity(i)
  return tonumber(self.entity_ids[i - 1])
end

function Iter:col_index(comp)
  comp = resolve_component(comp)
  local cid = comp.id
  for i = 0, self.col_count - 1 do
    if self.col_ids[i] == cid then
      return i
    end
  end
  return nil
end

function Iter:col_ptr(comp)
  comp = resolve_component(comp)
  local idx = self:col_index(comp)
  if idx == nil then
    return nil
  end
  if type(comp.ctype) == "string" then
    return ffi.cast(comp.ctype .. "*", self.columns[idx])
  end
  return self.columns[idx]
end

function Iter:col(comp, i)
  local ptr = self:col_ptr(comp)
  if ptr == nil then
    return nil
  end
  return ptr[i - 1]
end

local function make_iter(entity_ids, entity_count, columns, col_ids, col_sizes, col_count, dt, cb_id)
  return setmetatable({
    entity_ids = entity_ids,
    count = tonumber(entity_count),
    columns = columns,
    col_ids = col_ids,
    col_sizes = col_sizes,
    col_count = tonumber(col_count),
    dt = tonumber(dt),
    cb_id = tonumber(cb_id),
  }, Iter)
end

function M.register(name, components, fn, callback_id)
  local names = normalize_component_names(components)
  local function wrapper(entity_ids, entity_count, columns, col_ids, col_sizes, col_count, dt, cb_id)
    return fn(make_iter(entity_ids, entity_count, columns, col_ids, col_sizes, col_count, dt, cb_id))
  end
  return ecs.register_system(name, names, wrapper, callback_id)
end

function M.register_ex(name, include, exclude, fn, callback_id)
  local include_names = normalize_component_names(include)
  local exclude_names = normalize_component_names(exclude or {})
  local function wrapper(entity_ids, entity_count, columns, col_ids, col_sizes, col_count, dt, cb_id)
    return fn(make_iter(entity_ids, entity_count, columns, col_ids, col_sizes, col_count, dt, cb_id))
  end
  return ecs.register_system_ex(name, include_names, exclude_names, wrapper, callback_id)
end

function M.unregister(system_id)
  return ecs.unregister_system(system_id)
end

M.Iter = Iter

return M
