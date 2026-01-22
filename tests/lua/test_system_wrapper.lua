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
local sys = require("flecs_wrapper.bindings.lua.system_wrapper")

local function expect(cond, msg)
  if not cond then
    error("TEST FAILED: " .. msg)
  end
end

local function nearly_equal(a, b, eps)
  eps = eps or 1e-6
  return math.abs(a - b) <= eps
end

ecs.init()
ecs.set_threads(1)

local Position = comp.create("LuaSysPos", {
  {"x", comp.types.float},
  {"y", comp.types.float},
})
local Velocity = comp.create("LuaSysVel", {
  {"x", comp.types.float},
  {"y", comp.types.float},
})

local e1 = ent.create("LuaSysE1")
e1:set(Position, {x = 0, y = 0})
e1:set(Velocity, {x = 2, y = 0})

local e2 = ent.create("LuaSysE2")
e2:set(Position, {x = 1, y = 0})
e2:set(Velocity, {x = 3, y = 0})

local seen = {count = 0}
sys.register("LuaSysMove", {Position, Velocity}, function(it)
  for i = 1, it.count do
    local pos = it:col(Position, i)
    local vel = it:col(Velocity, i)
    pos.x = pos.x + vel.x * it.dt
    seen.count = seen.count + 1
  end
end)

ecs.progress(0.5)

local p1 = e1:get(Position)
local p2 = e2:get(Position)
expect(p1 ~= nil and p2 ~= nil, "get Position returned nil")
expect(nearly_equal(p1[0].x, 1.0), "unexpected position for e1")
expect(nearly_equal(p2[0].x, 2.5), "unexpected position for e2")
expect(seen.count >= 2, "system did not process entities")

print("test_system_wrapper.lua: OK")
ecs.fini()
