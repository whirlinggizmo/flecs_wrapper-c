local ecs = require("flecs_wrapper.bindings.lua.flecs_wrapper")
local component = require("flecs_wrapper.bindings.lua.component")

local M = {}

local Entity = {}
Entity.__index = Entity

local function resolve_component(comp)
  if type(comp) == "string" then
    local obj = component.get(comp)
    if not obj then
      error("Unknown component name: " .. tostring(comp))
    end
    return obj
  end
  if type(comp) == "table" and comp.id then
    return comp
  end
  error("component must be a name or component object")
end

local function resolve_entity(obj)
  if type(obj) == "table" and obj.id then
    return obj
  end
  error("object must be an entity")
end

local function resolve_pair_id(rel, obj)
  if type(rel) == "string" and type(obj) == "string" then
    return ecs.pair_register_by_name(rel, obj)
  end
  rel = resolve_component(rel)
  obj = resolve_entity(obj)
  return ecs.pair_register(rel.id, obj.id)
end

function M.create(name)
  local id = ecs.entity_create(name)
  if id == 0 then
    error("entity_create failed for " .. tostring(name))
  end
  return setmetatable({id = id}, Entity)
end

function M.wrap(id)
  return setmetatable({id = id}, Entity)
end


function Entity:add(comp)
  comp = resolve_component(comp)
  return ecs.entity_add_component(self.id, comp.id) ~= 0
end

function Entity:remove(comp)
  comp = resolve_component(comp)
  return ecs.entity_remove_component(self.id, comp.id) ~= 0
end

function Entity:has(comp)
  comp = resolve_component(comp)
  return ecs.entity_has_component(self.id, comp.id)
end

function Entity:set(comp, value)
  comp = resolve_component(comp)
  ecs.entity_add_component(self.id, comp.id)

  local ptr = value
  if type(value) == "table" then
    if type(comp.ctype) ~= "string" then
      error("component " .. tostring(comp.name) .. " has no ctype")
    end
    ptr = ecs.new(comp.ctype, value)
  end

  return ecs.entity_set_component(self.id, comp.id, ptr) ~= 0
end

function Entity:get(comp, cast_type)
  comp = resolve_component(comp)
  local ctype = cast_type
  if ctype == nil and type(comp.ctype) == "string" then
    -- add a "*" so we are casting to a struct pointer
    ctype = comp.ctype .. "*"
  end
  return ecs.entity_get_component(self.id, comp.id, ctype)
end

function Entity:mark(comp)
  comp = resolve_component(comp)
  ecs.entity_mark_component(self.id, comp.id)
end

function Entity:add_pair(rel, obj)
  local pair_id = resolve_pair_id(rel, obj)
  return ecs.entity_add_pair(self.id, pair_id) ~= 0
end

function Entity:remove_pair(rel, obj)
  local pair_id = resolve_pair_id(rel, obj)
  return ecs.entity_remove_pair(self.id, pair_id) ~= 0
end

function Entity:has_pair(rel, obj)
  local pair_id = resolve_pair_id(rel, obj)
  return ecs.entity_has_pair(self.id, pair_id)
end

function Entity:set_pair(rel, obj, value)
  local pair_id = resolve_pair_id(rel, obj)
  local ptr = value
  if type(value) == "table" then
    rel = resolve_component(rel)
    if type(rel.ctype) ~= "string" then
      error("component " .. tostring(rel.name) .. " has no ctype")
    end
    ptr = ecs.new(rel.ctype, value)
  end
  return ecs.entity_set_pair(self.id, pair_id, ptr) ~= 0
end

function Entity:get_pair(rel, obj, cast_type)
  local pair_id = resolve_pair_id(rel, obj)
  local ctype = cast_type
  if ctype == nil and type(rel) == "table" and type(rel.ctype) == "string" then
    ctype = rel.ctype .. "*"
  end
  return ecs.entity_get_pair(self.id, pair_id, ctype)
end

M.Entity = Entity

return M
