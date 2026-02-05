local function add_flecs_wrapper_path()
  local source = debug.getinfo(1, "S").source
  local path = source:sub(1, 1) == "@" and source:sub(2) or ""
  local dir = path:match("^(.*[/\\])") or "./"
  local module_root = dir .. "../../.."
  package.path = module_root .. "/?.lua;" .. module_root .. "/?/init.lua;" .. package.path
end

add_flecs_wrapper_path()

local ffi = require("ffi")
local ecs = require("flecs_wrapper.bindings.lua.flecs")

ffi.cdef[[
typedef struct Vec2 { float x; float y; } Vec2;
]]

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

-- component create / query
local vec_id = ecs.component_create("LuaCoreVec2", ffi.sizeof("Vec2"))
expect(vec_id ~= 0, "component_create failed")
expect(ecs.component_is_tag(vec_id) == false, "component_is_tag should be false for Vec2")
expect(ecs.component_id("LuaCoreVec2") == vec_id, "component_id mismatch")

-- entity create / set / get
local e1 = ecs.entity_create("CoreEntity")
expect(e1 ~= 0, "entity_create failed")
expect(ecs.entity_has_component(e1, vec_id) == false, "entity should not have component yet")

local v1 = ecs.new("Vec2", {x = 1, y = 2})
expect(ecs.entity_set_component(e1, vec_id, v1) ~= 0, "entity_set_component failed")
expect(ecs.entity_has_component(e1, vec_id) == true, "entity_has_component should be true")

local ptr = ecs.entity_get_component(e1, vec_id, "Vec2*")
expect(ptr ~= nil, "entity_get_component returned nil")
expect(ptr[0].x == 1 and ptr[0].y == 2, "entity_get_component data mismatch")

-- pair (low-level)
local e2 = ecs.entity_create("CorePairObj")
expect(e2 ~= 0, "entity_create for pair object failed")

local pair_id = ecs.pair_register(vec_id, e2)
expect(pair_id ~= 0, "pair_register failed")
expect(ecs.entity_has_pair(e1, pair_id) == false, "entity should not have pair initially")
expect(ecs.entity_add_pair(e1, pair_id) ~= 0, "entity_add_pair failed")
expect(ecs.entity_has_pair(e1, pair_id) == true, "entity should have pair after add")

local pv = ecs.new("Vec2", {x = 7, y = 8})
expect(ecs.entity_set_pair(e1, pair_id, pv) ~= 0, "entity_set_pair failed")
local pptr = ecs.entity_get_pair(e1, pair_id, "Vec2*")
expect(pptr ~= nil, "entity_get_pair returned nil")
expect(pptr[0].x == 7 and pptr[0].y == 8, "entity_get_pair data mismatch")

expect(ecs.entity_remove_pair(e1, pair_id) ~= 0, "entity_remove_pair failed")
expect(ecs.entity_has_pair(e1, pair_id) == false, "entity should not have pair after remove")

expect(ecs.pair_unregister(pair_id) == true, "pair_unregister failed")
expect(ecs.entity_add_pair(e1, pair_id) == 0, "entity_add_pair should fail after unregister")
local pair_id2 = ecs.pair_register(vec_id, e2)
expect(pair_id2 ~= 0, "pair_register failed after unregister")
expect(ecs.entity_add_pair(e1, pair_id2) ~= 0, "entity_add_pair failed after unregister")

-- observer (low-level)
local callback_id = 123
local seen = {
  add = 0,
  set = 0,
  last = nil,
  last_event = nil,
  last_component = nil,
  last_entity = nil,
}

local obs_id = ecs.register_observer({"LuaCoreVec2"}, {ecs.events.ON_ADD, ecs.events.ON_SET}, function(entity_ids, count, columns, column_component_ids, column_sizes, column_count, event_id, component_id, cb_id)
  expect(cb_id == callback_id, "callback_id mismatch")
  expect(count == 1, "expected exactly 1 entity")
  expect(column_count == 1, "expected exactly 1 column")
  expect(tonumber(column_component_ids[0]) == vec_id, "column_component_id mismatch")
  expect(tonumber(column_sizes[0]) == ffi.sizeof("Vec2"), "column_sizes mismatch")

  seen.last_event = tonumber(event_id)
  seen.last_component = tonumber(component_id)
  seen.last_entity = tonumber(entity_ids[0])

  local v = ffi.cast("Vec2*", columns[0])
  expect(v ~= nil, "columns[0] is nil")
  seen.last = {x = v[0].x, y = v[0].y}

  if seen.last_event == ecs.events.ON_ADD then
    seen.add = seen.add + 1
  elseif seen.last_event == ecs.events.ON_SET then
    seen.set = seen.set + 1
  end
end, callback_id)
expect(obs_id ~= 0, "observer id was 0")

-- First set: should at least emit ON_SET; may also emit ON_ADD depending on Flecs behavior.
ecs.entity_set_component(e1, vec_id, ecs.new("Vec2", {x = 3, y = 4}))

-- Second set: should emit ON_SET.
ecs.entity_set_component(e1, vec_id, ecs.new("Vec2", {x = 5, y = 6}))

ecs.progress(0)

expect(seen.last_component == vec_id, "observer reported wrong component_id")
expect(seen.last_entity == e1, "observer reported wrong entity_id")
expect(seen.set >= 1, "expected ON_SET observer to fire at least once")
expect(seen.last ~= nil and seen.last.x == 5 and seen.last.y == 6, "expected last observed value to be 5,6")

expect(ecs.unregister_observer(obs_id), "failed to unregister observer")

-- error paths
expect_error(function()
  ecs.register_observer({"NoSuchComponent"}, {ecs.events.ON_ADD}, function() end)
end, "expected error for unknown component")

expect_error(function()
  ecs.register_observer({"LuaCoreVec2"}, {99}, function() end)
end, "expected error for invalid event id")

-- entity destroy
expect(ecs.entity_destroy(e1) ~= 0, "entity_destroy failed")

ecs.fini()
print(string.format("test_flecs_wrapper.lua: OK (set=%d add=%d)", seen.set, seen.add))
