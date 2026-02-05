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

local function expect_error(fn, msg)
  local ok, _ = pcall(fn)
  expect(not ok, msg)
end

ecs.init()
ecs.set_threads(1)

local Position = assert(comp.create("LuaObsPos", {
  {"x", comp.types.float},
  {"y", comp.types.float},
}), "component create returned nil for LuaObsPos")

local seen = {
  add = 0,
  last_entity = 0,
  last_component = 0,
}

local obs_id = obs.register({Position}, {ecs.events.ON_ADD}, function(it)
  seen.add = seen.add + 1
  seen.last_entity = it:entity(1)
  seen.last_component = it.component_id
end)
expect(obs_id ~= 0, "observer id was 0")

local e = ent.create("ObsEntity")
e:set(Position, {x = 1.0, y = 2.0})

ecs.progress(0)

expect(seen.add >= 1, "observer did not fire for ON_ADD")
expect(seen.last_entity == e.id, "observer saw wrong entity")
expect(seen.last_component == Position.id, "observer saw wrong component")

expect(obs.unregister(obs_id), "failed to unregister observer")

local PositionMore = comp.create("LuaObsMorePos", {
  {"x", comp.types.float},
  {"y", comp.types.float},
})
local VelocityMore = comp.create("LuaObsMoreVel", {
  {"x", comp.types.float},
  {"y", comp.types.float},
})

local seen_more = {
  set = 0,
  remove = 0,
  last_entity = 0,
}

local obs_set_id = obs.register({PositionMore}, {ecs.events.ON_SET}, function(it)
  seen_more.set = seen_more.set + 1
  seen_more.last_entity = it:entity(1)
end)
expect(obs_set_id ~= 0, "observer ON_SET id was 0")

local obs_remove_id = obs.register({PositionMore}, {ecs.events.ON_REMOVE}, function(it)
  seen_more.remove = seen_more.remove + 1
end)
expect(obs_remove_id ~= 0, "observer ON_REMOVE id was 0")

local multi_seen = {count = 0, pos_x = 0, vel_x = 0}
local obs_multi_id = obs.register({PositionMore, VelocityMore}, {ecs.events.ON_SET}, function(it)
  multi_seen.count = multi_seen.count + 1
  local pos = it:col(PositionMore, 1)
  local vel = it:col(VelocityMore, 1)
  if pos and vel then
    multi_seen.pos_x = pos.x
    multi_seen.vel_x = vel.x
  end
end)
expect(obs_multi_id ~= 0, "observer multi id was 0")

local e2 = ent.create("ObsMoreEntity")
e2:set(VelocityMore, {x = 2.0, y = 0.0})
e2:set(PositionMore, {x = 1.0, y = 3.0})
e2:set(PositionMore, {x = 4.0, y = 5.0})

ecs.progress(0)

expect(seen_more.set >= 2, "expected ON_SET observer to fire")
expect(seen_more.last_entity == e2.id, "observer reported wrong entity id")
expect(multi_seen.count >= 1, "multi-component observer did not fire")
expect(multi_seen.pos_x == 4.0, "multi-component observer saw wrong Position.x")
expect(multi_seen.vel_x == 2.0, "multi-component observer saw wrong Velocity.x")

e2:remove(PositionMore)
ecs.progress(0)

expect(seen_more.remove >= 1, "expected ON_REMOVE observer to fire")

expect_error(function()
  obs.register({"NoSuchComponent"}, {ecs.events.ON_ADD}, function() end)
end, "expected error for unknown component")

expect_error(function()
  obs.register({PositionMore}, {99}, function() end)
end, "expected error for invalid event id")

expect(obs.unregister(obs_set_id), "failed to unregister ON_SET observer")
expect(obs.unregister(obs_remove_id), "failed to unregister ON_REMOVE observer")
expect(obs.unregister(obs_multi_id), "failed to unregister multi observer")

print("test_observer.lua: OK (add=" .. tostring(seen.add) .. ", set=" .. tostring(seen_more.set) .. ", remove=" .. tostring(seen_more.remove) .. ")")
ecs.fini()
