local ffi = require("ffi")
local ecs = require("flecs_wrapper.bindings.lua.flecs")

ffi.cdef[[
typedef struct Counter { int32_t count; } Counter;
typedef struct Vec2 { float x; float y; } Vec2;
]]

local function expect(cond, msg)
  if not cond then
    error("TEST FAILED: " .. msg)
  end
end

ecs.init()
ecs.set_threads(1)

local cases = {}

local function add_case(name, expect_e1_moved, expect_e2_moved)
  local case = {
    name = name,
    expect_e1_moved = expect_e1_moved,
    expect_e2_moved = expect_e2_moved,
    processed = {},
  }
  table.insert(cases, case)
  return case
end

local function create_component(name, ctype)
  local id = ecs.component_create(name, ffi.sizeof(ctype))
  expect(id ~= 0, "component_create failed: " .. name)
  return id
end

-- Case 1: exclude matches entity 1 only.
do
  local case = add_case("exclude_match", false, true)
  case.pos_id = create_component("LuaPosA", "Vec2")
  case.vel_id = create_component("LuaVelA", "Vec2")
  case.excl_id = create_component("LuaExclA", "Counter")

  case.e1 = ecs.entity_create("WithExcludeA")
  case.e2 = ecs.entity_create("NoExcludeA")

  ecs.entity_set_component(case.e1, case.pos_id, ecs.new("Vec2", {x = 0, y = 0}))
  ecs.entity_set_component(case.e1, case.vel_id, ecs.new("Vec2", {x = 1, y = 0}))
  ecs.entity_set_component(case.e1, case.excl_id, ecs.new("Counter", {count = 1}))

  ecs.entity_set_component(case.e2, case.pos_id, ecs.new("Vec2", {x = 0, y = 0}))
  ecs.entity_set_component(case.e2, case.vel_id, ecs.new("Vec2", {x = 1, y = 0}))

  ecs.register_system_ex("MoveSystemExLuaA", {"LuaPosA", "LuaVelA"}, {"LuaExclA"}, function(entity_ids, count, columns, _, _, _, dt, _)
    local pos = ffi.cast("Vec2*", columns[0])
    local vel = ffi.cast("Vec2*", columns[1])
    for i = 0, count - 1 do
      pos[i].x = pos[i].x + vel[i].x * dt
      pos[i].y = pos[i].y + vel[i].y * dt
      case.processed[entity_ids[i]] = (case.processed[entity_ids[i]] or 0) + 1
    end
  end)
end

-- Case 2: exclude empty.
do
  local case = add_case("exclude_empty", true, true)
  case.pos_id = create_component("LuaPosB", "Vec2")
  case.vel_id = create_component("LuaVelB", "Vec2")

  case.e1 = ecs.entity_create("IncludeOnlyB1")
  case.e2 = ecs.entity_create("IncludeOnlyB2")

  ecs.entity_set_component(case.e1, case.pos_id, ecs.new("Vec2", {x = 0, y = 0}))
  ecs.entity_set_component(case.e1, case.vel_id, ecs.new("Vec2", {x = 1, y = 0}))
  ecs.entity_set_component(case.e2, case.pos_id, ecs.new("Vec2", {x = 0, y = 0}))
  ecs.entity_set_component(case.e2, case.vel_id, ecs.new("Vec2", {x = 1, y = 0}))

  ecs.register_system_ex("MoveSystemExLuaB", {"LuaPosB", "LuaVelB"}, {}, function(entity_ids, count, columns, _, _, _, dt, _)
    local pos = ffi.cast("Vec2*", columns[0])
    local vel = ffi.cast("Vec2*", columns[1])
    for i = 0, count - 1 do
      pos[i].x = pos[i].x + vel[i].x * dt
      pos[i].y = pos[i].y + vel[i].y * dt
      case.processed[entity_ids[i]] = (case.processed[entity_ids[i]] or 0) + 1
    end
  end)
end

-- Case 3: exclude missing.
do
  local case = add_case("exclude_missing", true, true)
  case.pos_id = create_component("LuaPosC", "Vec2")
  case.vel_id = create_component("LuaVelC", "Vec2")
  case.excl_id = create_component("LuaExclC", "Counter")

  case.e1 = ecs.entity_create("ExcludeMissingC1")
  case.e2 = ecs.entity_create("ExcludeMissingC2")

  ecs.entity_set_component(case.e1, case.pos_id, ecs.new("Vec2", {x = 0, y = 0}))
  ecs.entity_set_component(case.e1, case.vel_id, ecs.new("Vec2", {x = 1, y = 0}))
  ecs.entity_set_component(case.e2, case.pos_id, ecs.new("Vec2", {x = 0, y = 0}))
  ecs.entity_set_component(case.e2, case.vel_id, ecs.new("Vec2", {x = 1, y = 0}))

  ecs.register_system_ex("MoveSystemExLuaC", {"LuaPosC", "LuaVelC"}, {"LuaExclC"}, function(entity_ids, count, columns, _, _, _, dt, _)
    local pos = ffi.cast("Vec2*", columns[0])
    local vel = ffi.cast("Vec2*", columns[1])
    for i = 0, count - 1 do
      pos[i].x = pos[i].x + vel[i].x * dt
      pos[i].y = pos[i].y + vel[i].y * dt
      case.processed[entity_ids[i]] = (case.processed[entity_ids[i]] or 0) + 1
    end
  end)
end

-- Case 4: multiple excludes.
do
  local case = add_case("exclude_multiple", false, true)
  case.pos_id = create_component("LuaPosD", "Vec2")
  case.vel_id = create_component("LuaVelD", "Vec2")
  case.excl1_id = create_component("LuaExclD1", "Counter")
  case.excl2_id = create_component("LuaExclD2", "Counter")

  case.e1 = ecs.entity_create("ExcludeMultiD1")
  case.e2 = ecs.entity_create("ExcludeMultiD2")

  ecs.entity_set_component(case.e1, case.pos_id, ecs.new("Vec2", {x = 0, y = 0}))
  ecs.entity_set_component(case.e1, case.vel_id, ecs.new("Vec2", {x = 1, y = 0}))
  ecs.entity_set_component(case.e1, case.excl1_id, ecs.new("Counter", {count = 1}))

  ecs.entity_set_component(case.e2, case.pos_id, ecs.new("Vec2", {x = 0, y = 0}))
  ecs.entity_set_component(case.e2, case.vel_id, ecs.new("Vec2", {x = 1, y = 0}))

  ecs.register_system_ex("MoveSystemExLuaD", {"LuaPosD", "LuaVelD"}, {"LuaExclD1", "LuaExclD2"}, function(entity_ids, count, columns, _, _, _, dt, _)
    local pos = ffi.cast("Vec2*", columns[0])
    local vel = ffi.cast("Vec2*", columns[1])
    for i = 0, count - 1 do
      pos[i].x = pos[i].x + vel[i].x * dt
      pos[i].y = pos[i].y + vel[i].y * dt
      case.processed[entity_ids[i]] = (case.processed[entity_ids[i]] or 0) + 1
    end
  end)
end

ecs.progress(1.0)

for _, case in ipairs(cases) do
  local pos1 = ecs.entity_get_component(case.e1, case.pos_id, "Vec2*")
  local pos2 = ecs.entity_get_component(case.e2, case.pos_id, "Vec2*")

  if case.expect_e1_moved then
    expect(pos1[0].x == 1 and pos1[0].y == 0, case.name .. ": expected e1 moved")
    expect((case.processed[case.e1] or 0) > 0, case.name .. ": expected e1 processed")
  else
    expect(pos1[0].x == 0 and pos1[0].y == 0, case.name .. ": expected e1 not moved")
    expect((case.processed[case.e1] or 0) == 0, case.name .. ": expected e1 not processed")
  end

  if case.expect_e2_moved then
    expect(pos2[0].x == 1 and pos2[0].y == 0, case.name .. ": expected e2 moved")
    expect((case.processed[case.e2] or 0) > 0, case.name .. ": expected e2 processed")
  else
    expect(pos2[0].x == 0 and pos2[0].y == 0, case.name .. ": expected e2 not moved")
    expect((case.processed[case.e2] or 0) == 0, case.name .. ": expected e2 not processed")
  end
end

print(string.format("test_system_ex.lua: OK (%d cases)", #cases))
ecs.fini()
