local ecs = require("flecs_wrapper.bindings.lua.flecs")
local ffi = ecs.ffi

local M = {}

M.types = {
  float = "float",
  int = "int",
  uint8 = "uint8_t",
  int32 = "int32_t",
  uint32 = "uint32_t",
}

local Component = {}
Component.__index = Component

local function resolve_size(ctype_or_size)
  if type(ctype_or_size) == "string" then
    return ffi.sizeof(ctype_or_size)
  end
  error("ctype_or_size must be a ctype string")
end

local function resolve_ctype(value)
  if type(value) ~= "string" then
    error("field type must be a string")
  end
  return M.types[value] or value
end

function Component:new(init)
  if not self.ctype then
    error("component " .. tostring(self.name) .. " has no ctype")
  end
  return ecs.new(self.ctype, init)
end

function Component:is_tag()
  return ecs.component_is_tag(self.id)
end

function Component:add(entity_id)
  return ecs.entity_add_component(entity_id, self.id) ~= 0
end

function Component:remove(entity_id)
  return ecs.entity_remove_component(entity_id, self.id) ~= 0
end

function Component:has(entity_id)
  return ecs.entity_has_component(entity_id, self.id)
end

function Component:set(entity_id, value)
  local ptr = value
  if type(value) == "table" then
    if not self.ctype then
      error("component " .. tostring(self.name) .. " has no ctype")
    end
    ptr = ecs.new(self.ctype, value)
  end
  return ecs.entity_set_component(entity_id, self.id, ptr) ~= 0
end

function Component:get(entity_id, cast_type)
  return ecs.entity_get_component(entity_id, self.id, cast_type or self.ctype)
end

function Component:mark(entity_id)
  ecs.entity_mark_component(entity_id, self.id)
end

function M.define(name, fields)
  if type(name) ~= "string" or name == "" then
    error("name must be a non-empty string")
  end

  -- check if type already exists
  local exists = pcall(ffi.typeof, name)
  if exists then
    print("Warning: ctype " .. tostring(name) .. " already defined, skipping definition")
    return
  end

  if type(fields) ~= "table" then
    error("fields must be an array of {name=..., type=...}")
  end


  local lines = {}
  for i, field in ipairs(fields) do
    if type(field) ~= "table" then
      error("field must be a table at index " .. i)
    end
    local field_name = field.name or field[1]
    local field_type = field.type or field[2]
    if type(field_name) ~= "string" or field_name == "" then
      error("field name must be a non-empty string at index " .. i)
    end
    field_type = resolve_ctype(field_type)
    lines[#lines + 1] = "  " .. field_type .. " " .. field_name .. ";"
  end

  local cdef = "typedef struct " .. name .. " {\n" ..
    table.concat(lines, "\n") .. "\n} " .. name .. ";"
  
    -- define the struct in ffi
  local ok, err = pcall(ffi.cdef, cdef)
  if not ok then
    error("ffi.cdef failed for " .. tostring(name) .. ": " .. tostring(err))
  end
end

function M.register(name, ctype_or_size)
  if ecs.component_id(name) ~= 0 then
    print("component already registered: " .. tostring(name))
    return M.get(name, ctype_or_size)
  end
  local size
  if type(ctype_or_size) == "number" then
    size = ctype_or_size
  else
    size = resolve_size(ctype_or_size)
  end
  local id = ecs.component_create(name, size)
  if id == 0 then
    error("component_create failed for " .. tostring(name))
  end
  return setmetatable({name = name, id = id, ctype = ctype_or_size}, Component)
end

-- convenience function to define and register a component
function M.create(name, def)
  if type(def) == "table" then
    M.define(name, def)
    return M.register(name, name)
  end
  return M.register(name, def)
end


function M.tag(name)
  local id = ecs.component_create_tag(name)
  if id == 0 then
    error("component_create_tag failed for " .. tostring(name))
  end
  return setmetatable({name = name, id = id, ctype = nil}, Component)
end

function M.get(name, ctype)
  local id = ecs.component_id(name)
  if id == 0 then
    return nil
  end
  return setmetatable({name = name, id = id, ctype = ctype}, Component)
end

M.Component = Component

return M
