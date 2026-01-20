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

ecs.init()
ecs.set_threads(1)

local vec_id = ecs.component_create("LuaObsVec2", ffi.sizeof("Vec2"))
expect(vec_id ~= 0, "component_create failed")

local e1 = ecs.entity_create("ObserverEntity")
expect(e1 ~= 0, "entity_create failed")

local callback_id = 123
local seen = {
  add = 0,
  set = 0,
  last = nil,
  last_event = nil,
  last_component = nil,
  last_entity = nil,
}

ecs.register_observer({"LuaObsVec2"}, {ecs.events.ON_ADD, ecs.events.ON_SET}, function(entity_ids, count, columns, column_component_ids, column_sizes, column_count, event_id, component_id, cb_id)
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

-- First set: should at least emit ON_SET; may also emit ON_ADD depending on Flecs behavior.
ecs.entity_set_component(e1, vec_id, ecs.new("Vec2", {x = 1, y = 2}))

-- Second set: should emit ON_SET.
ecs.entity_set_component(e1, vec_id, ecs.new("Vec2", {x = 3, y = 4}))

-- Ensure any deferred observer work gets processed (if applicable).
ecs.progress(0)

expect(seen.last_component == vec_id, "observer reported wrong component_id")
expect(seen.last_entity == e1, "observer reported wrong entity_id")
expect(seen.set >= 1, "expected ON_SET observer to fire at least once")
expect(seen.last ~= nil and seen.last.x == 3 and seen.last.y == 4, "expected last observed value to be 3,4")

print(string.format("test_observer.lua: OK (set=%d add=%d)", seen.set, seen.add))
ecs.fini()
