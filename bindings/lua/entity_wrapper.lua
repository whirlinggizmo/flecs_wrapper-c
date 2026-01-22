local ecs = require("flecs_wrapper.bindings.lua.flecs")
local component = require("flecs_wrapper.bindings.lua.component_wrapper")

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

M.Entity = Entity

return M
