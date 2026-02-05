local function add_flecs_wrapper_path()
  local source = debug.getinfo(1, "S").source
  local path = source:sub(1, 1) == "@" and source:sub(2) or ""
  local dir = path:match("^(.*[/\\])") or "./"
  local module_root = dir .. "../../.."
  package.path = module_root .. "/?.lua;" .. module_root .. "/?/init.lua;" .. package.path
end

add_flecs_wrapper_path()

local ecs = require("flecs_wrapper.bindings.lua.flecs")
local comp = require("flecs_wrapper.bindings.lua.component")
local ent = require("flecs_wrapper.bindings.lua.entity")
local obs = require("flecs_wrapper.bindings.lua.observer")

local function expect(cond, msg)
  if not cond then
    error("TEST FAILED: " .. msg)
  end
end

ecs.init()
ecs.set_threads(1)

local Position = comp.create("LuaObsExPos", {
  {"x", comp.types.float},
  {"y", comp.types.float},
})
local ExcludeTag = comp.tag("LuaObsExTag")

local seen = {add = 0}

local obs_id = obs.register_ex({Position}, {ExcludeTag}, {ecs.events.ON_ADD}, function(it)
  seen.add = seen.add + 1
end)
expect(obs_id ~= 0, "observer id was 0")

local e1 = ent.create("ObsExEntity1")
e1:set(Position, {x = 1.0, y = 2.0})

local e2 = ent.create("ObsExEntity2")
e2:add(ExcludeTag)
e2:set(Position, {x = 3.0, y = 4.0})

ecs.progress(0)

expect(seen.add == 1, "observer should ignore excluded entities")

expect(obs.unregister(obs_id), "failed to unregister observer")

print("test_observer_ex.lua: OK (add=" .. tostring(seen.add) .. ")")
ecs.fini()
