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

local function expect(cond, msg)
  if not cond then
    error("TEST FAILED: " .. msg)
  end
end

ecs.init()
ecs.set_threads(1)

local Position = comp.create("LuaEntPos", {
  {"x", comp.types.float},
  {"y", comp.types.float},
})
local Tag = comp.tag("LuaEntTag")

local e = ent.create("LuaEnt")
expect(e.id ~= 0, "entity create failed")

expect(e:has(Position) == false, "entity should not have Position initially")
expect(e:add(Position) == true, "entity add Position failed")
expect(e:has(Position) == true, "entity should have Position after add")

expect(e:has("LuaEntTag") == false, "entity should not have Tag initially")
expect(e:add("LuaEntTag") == true, "entity add Tag by name failed")
expect(e:has("LuaEntTag") == true, "entity should have Tag after add")

expect(e:set(Position, {x = 2.5, y = -1.0}) == true, "entity set Position failed")
local p = e:get(Position)
expect(p ~= nil, "entity get Position returned nil")
expect(p[0].x == 2.5, "expected Position.x == 2.5")
expect(p[0].y == -1.0, "expected Position.y == -1.0")

e:mark(Position)

expect(e:remove("LuaEntTag") == true, "entity remove Tag failed")
expect(e:has("LuaEntTag") == false, "entity should not have Tag after remove")

local PairRel = comp.create("LuaPairRel", {
  {"x", comp.types.float},
  {"y", comp.types.float},
})
local PairObj = ent.create("LuaPairObj")

expect(e:has_pair(PairRel, PairObj) == false, "entity should not have pair initially")
expect(e:add_pair(PairRel, PairObj) == true, "entity add pair failed")
expect(e:has_pair(PairRel, PairObj) == true, "entity should have pair after add")

expect(e:set_pair(PairRel, PairObj, {x = 7.0, y = 8.0}) == true, "entity set pair failed")
local pp = e:get_pair(PairRel, PairObj)
expect(pp ~= nil, "entity get pair returned nil")
expect(pp[0].x == 7.0, "expected pair.x == 7.0")
expect(pp[0].y == 8.0, "expected pair.y == 8.0")

expect(e:remove_pair(PairRel, PairObj) == true, "entity remove pair failed")
expect(e:has_pair(PairRel, PairObj) == false, "entity should not have pair after remove")

print("test_entity.lua: OK")
ecs.fini()
