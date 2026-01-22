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

local function expect(cond, msg)
  if not cond then
    error("TEST FAILED: " .. msg)
  end
end


ecs.init()
ecs.set_threads(1)

local Position = assert(comp.create("LuaWrapPos", {
  {"x", comp.types.float},
  {"y", comp.types.float},
}), "component create returned nil for LuaWrapPos")
expect(Position.id ~= 0, "component create failed for LuaWrapPos")
expect(Position.ctype == "LuaWrapPos", "ctype should match component name")
expect(Position:is_tag() == false, "LuaWrapPos should not be a tag")

local Tag = assert(comp.tag("LuaWrapTag"), "tag create returned nil for LuaWrapTag")
expect(Tag.id ~= 0, "tag create failed for LuaWrapTag")
expect(Tag:is_tag() == true, "LuaWrapTag should be a tag")
expect(Tag.ctype == nil, "tag should not have ctype")

local fetched = assert(comp.get("LuaWrapPos", "LuaWrapPos"), "get returned nil for LuaWrapPos")
expect(fetched.id == Position.id, "get should return same id for LuaWrapPos")

local existing = assert(comp.register("LuaWrapPos", "LuaWrapPos"), "register returned nil for LuaWrapPos")
expect(existing.id == Position.id, "register should return same id for existing component")

print("test_component_wrapper.lua: OK")
ecs.fini()
