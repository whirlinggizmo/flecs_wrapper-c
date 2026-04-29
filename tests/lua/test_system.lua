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
local sys = require("flecs_wrapper.bindings.lua.system")

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
local sys_id = sys.register("LuaSysMove", {Position, Velocity}, function(it)
  for i = 1, it.count do
    local pos = it:col(Position, i)
    local vel = it:col(Velocity, i)
    pos.x = pos.x + vel.x * it.dt
    seen.count = seen.count + 1
  end
end)
expect(sys_id ~= 0, "system id was 0")

ecs.progress(0.5)

local p1 = e1:get(Position)
local p2 = e2:get(Position)
expect(p1 ~= nil and p2 ~= nil, "get Position returned nil")
expect(nearly_equal(p1 ~= nil and p1[0].x or 0, 1.0), "unexpected position for e1")
expect(nearly_equal(p2 ~= nil and p2[0].x or 0, 2.5), "unexpected position for e2")
expect(seen.count >= 2, "system did not process entities")

expect(sys.unregister(sys_id), "failed to unregister system")

print("test_system.lua: OK")
ecs.fini()
