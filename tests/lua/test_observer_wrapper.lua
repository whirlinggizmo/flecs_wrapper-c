local function add_flecs_wrapper_path()
  local source = debug.getinfo(1, "S").source
  local path = source:sub(1, 1) == "@" and source:sub(2) or ""
  local dir = path:match("^(.*[/\\])") or "./"
  local module_root = dir .. "../../.."
  package.path = module_root .. "/?.lua;" .. module_root .. "/?/init.lua;" .. package.path
end

add_flecs_wrapper_path()

local ecs = require("flecs_wrapper.bindings.lua.flecs")
local comp = require("flecs_wrapper.bindings.lua.component_wrapper")
local ent = require("flecs_wrapper.bindings.lua.entity_wrapper")
local obs = require("flecs_wrapper.bindings.lua.observer_wrapper")

local function expect(cond, msg)
  if not cond then
    error("TEST FAILED: " .. msg)
  end
end

ecs.init()
ecs.set_threads(1)

local Position = comp.create("LuaObsPos", {
  {"x", comp.types.float},
  {"y", comp.types.float},
})

local seen = {
  add = 0,
  last_entity = 0,
  last_component = 0,
}

obs.register({Position}, {ecs.events.ON_ADD}, function(it)
  seen.add = seen.add + 1
  seen.last_entity = it:entity(1)
  seen.last_component = it.component_id
end)

local e = ent.create("ObsEntity")
e:set(Position, {x = 1.0, y = 2.0})

ecs.progress(0)

expect(seen.add >= 1, "observer did not fire for ON_ADD")
expect(seen.last_entity == e.id, "observer saw wrong entity")
expect(seen.last_component == Position.id, "observer saw wrong component")

print("test_observer_wrapper.lua: OK (add=" .. tostring(seen.add) .. ")")
ecs.fini()
