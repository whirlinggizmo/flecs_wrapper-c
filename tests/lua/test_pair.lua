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
local pair = require("flecs_wrapper.bindings.lua.pair")

local function expect(cond, msg)
  if not cond then
    error("TEST FAILED: " .. msg)
  end
end

ecs.init()
ecs.set_threads(1)

local Rel = comp.create("LuaPairRel2", {
  {"x", comp.types.float},
  {"y", comp.types.float},
})
local Obj = ent.create("LuaPairObj2")
local Host = ent.create("LuaPairHost2")

local p = pair.register(Rel, Obj)
expect(p.id ~= 0, "pair register failed")

expect(ecs.entity_has_pair(Host.id, p.id) == false, "host should not have pair initially")
expect(ecs.entity_add_pair(Host.id, p.id) ~= 0, "entity_add_pair failed")
expect(ecs.entity_has_pair(Host.id, p.id) == true, "host should have pair after add")
expect(ecs.entity_remove_pair(Host.id, p.id) ~= 0, "entity_remove_pair failed")
expect(ecs.entity_has_pair(Host.id, p.id) == false, "host should not have pair after remove")

expect(pair.unregister(p) == true, "pair unregister failed")
expect(ecs.entity_add_pair(Host.id, p.id) == 0, "entity_add_pair should fail after unregister")

print("test_pair.lua: OK")
ecs.fini()
