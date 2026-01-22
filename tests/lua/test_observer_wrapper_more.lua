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

local function expect_error(fn, msg)
  local ok, _ = pcall(fn)
  expect(not ok, msg)
end

ecs.init()
ecs.set_threads(1)

local Position = comp.create("LuaObsMorePos", {
  {"x", comp.types.float},
  {"y", comp.types.float},
})
local Velocity = comp.create("LuaObsMoreVel", {
  {"x", comp.types.float},
  {"y", comp.types.float},
})

local seen = {
  set = 0,
  remove = 0,
  last_entity = 0,
}

obs.register({Position}, {ecs.events.ON_SET}, function(it)
  seen.set = seen.set + 1
  seen.last_entity = it:entity(1)
end)

obs.register({Position}, {ecs.events.ON_REMOVE}, function(it)
  seen.remove = seen.remove + 1
end)

local multi_seen = {count = 0, pos_x = 0, vel_x = 0}
obs.register({Position, Velocity}, {ecs.events.ON_SET}, function(it)
  multi_seen.count = multi_seen.count + 1
  local pos = it:col(Position, 1)
  local vel = it:col(Velocity, 1)
  if pos and vel then
    multi_seen.pos_x = pos.x
    multi_seen.vel_x = vel.x
  end
end)

local e = ent.create("ObsMoreEntity")
e:set(Velocity, {x = 2.0, y = 0.0})
e:set(Position, {x = 1.0, y = 3.0})
e:set(Position, {x = 4.0, y = 5.0})

ecs.progress(0)

expect(seen.set >= 2, "expected ON_SET observer to fire")
expect(seen.last_entity == e.id, "observer reported wrong entity id")
expect(multi_seen.count >= 1, "multi-component observer did not fire")
expect(multi_seen.pos_x == 4.0, "multi-component observer saw wrong Position.x")
expect(multi_seen.vel_x == 2.0, "multi-component observer saw wrong Velocity.x")

e:remove(Position)
ecs.progress(0)

expect(seen.remove >= 1, "expected ON_REMOVE observer to fire")

expect_error(function()
  obs.register({"NoSuchComponent"}, {ecs.events.ON_ADD}, function() end)
end, "expected error for unknown component")

expect_error(function()
  obs.register({Position}, {99}, function() end)
end, "expected error for invalid event id")

print("test_observer_wrapper_more.lua: OK (set=" .. tostring(seen.set) .. ", remove=" .. tostring(seen.remove) .. ")")
ecs.fini()
