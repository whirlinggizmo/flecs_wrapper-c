local ecs = require("flecs_wrapper.bindings.lua.flecs_wrapper")
local component = require("flecs_wrapper.bindings.lua.component")
local entity = require("flecs_wrapper.bindings.lua.entity")

local M = {}

local Pair = {}
Pair.__index = Pair

local function resolve_relation(rel)
  if type(rel) == "string" then
    local comp = component.get(rel)
    if not comp then
      error("Unknown component name: " .. tostring(rel))
    end
    return comp
  end
  if type(rel) == "table" and rel.id then
    return rel
  end
  error("relation must be a component or name")
end

local function resolve_entity(obj)
  if type(obj) == "table" and obj.id then
    return obj
  end
  error("object must be an entity")
end

function M.register(relation, obj)
  if type(relation) == "string" and type(obj) == "string" then
    local id = ecs.pair_register_by_name(relation, obj)
    if id == 0 then
      error("pair_register failed")
    end
    return setmetatable({id = id}, Pair)
  end
  local rel = resolve_relation(relation)
  local ent = resolve_entity(obj)
  local id = ecs.pair_register(rel.id, ent.id)
  if id == 0 then
    error("pair_register failed")
  end
  return setmetatable({id = id}, Pair)
end

function M.register_entity(relation, obj)
  local rel = resolve_entity(relation)
  local ent = resolve_entity(obj)
  local id = ecs.pair_register_entity(rel.id, ent.id)
  if id == 0 then
    error("pair_register failed")
  end
  return setmetatable({id = id}, Pair)
end

function M.register_by_name(relation_name, object_name)
  local id = ecs.pair_register_by_name(relation_name, object_name)
  if id == 0 then
    error("pair_register failed")
  end
  return setmetatable({id = id}, Pair)
end

function M.unregister(pair_or_id)
  local id = pair_or_id
  if type(pair_or_id) == "table" and pair_or_id.id then
    id = pair_or_id.id
  end
  return ecs.pair_unregister(id)
end

M.Pair = Pair

return M
