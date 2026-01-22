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
typedef struct Counter { int32_t count; } Counter;
]]

local function expect(cond, msg)
  if not cond then
    error("TEST FAILED: " .. msg)
  end
end

ecs.init()
ecs.set_threads(1)

local counter_id = ecs.component_create("LuaCounter", ffi.sizeof("Counter"))
expect(counter_id ~= 0, "component_create LuaCounter failed")
expect(ecs.component_is_tag(counter_id) == false, "expected LuaCounter not to be a tag")

local tag_id = ecs.component_create_tag("LuaTag")
expect(tag_id ~= 0, "component_create_tag LuaTag failed")
expect(ecs.component_is_tag(tag_id) == true, "expected LuaTag to be a tag")

local e1 = ecs.entity_create("ComponentTestEntity")
expect(e1 ~= 0, "entity_create failed")

-- Initially absent
expect(ecs.entity_has_component(e1, counter_id) == false, "counter should not be present initially")
expect(ecs.entity_has_component_by_name(e1, "LuaCounter") == false, "counter(by_name) should not be present initially")

-- Add/remove data component by id
expect(ecs.entity_add_component(e1, counter_id) ~= 0, "entity_add_component(counter) failed")
expect(ecs.entity_has_component(e1, counter_id) == true, "counter should be present after add")
expect(ecs.entity_remove_component(e1, counter_id) ~= 0, "entity_remove_component(counter) failed")
expect(ecs.entity_has_component(e1, counter_id) == false, "counter should be absent after remove")

-- Add/remove data component by name
expect(ecs.entity_add_component_by_name(e1, "LuaCounter") == true, "entity_add_component_by_name(counter) failed")
expect(ecs.entity_has_component_by_name(e1, "LuaCounter") == true, "counter(by_name) should be present after add")
expect(ecs.entity_remove_component_by_name(e1, "LuaCounter") == true, "entity_remove_component_by_name(counter) failed")
expect(ecs.entity_has_component_by_name(e1, "LuaCounter") == false, "counter(by_name) should be absent after remove")

-- Add/remove tag by id
expect(ecs.entity_has_component(e1, tag_id) == false, "tag should not be present initially")
expect(ecs.entity_add_component(e1, tag_id) ~= 0, "entity_add_component(tag) failed")
expect(ecs.entity_has_component(e1, tag_id) == true, "tag should be present after add")
expect(ecs.entity_remove_component(e1, tag_id) ~= 0, "entity_remove_component(tag) failed")
expect(ecs.entity_has_component(e1, tag_id) == false, "tag should be absent after remove")

-- Add/remove tag by name
expect(ecs.entity_add_component_by_name(e1, "LuaTag") == true, "entity_add_component_by_name(tag) failed")
expect(ecs.entity_has_component_by_name(e1, "LuaTag") == true, "tag(by_name) should be present after add")
expect(ecs.entity_remove_component_by_name(e1, "LuaTag") == true, "entity_remove_component_by_name(tag) failed")
expect(ecs.entity_has_component_by_name(e1, "LuaTag") == false, "tag(by_name) should be absent after remove")

-- Set/get/remove data component
expect(ecs.entity_set_component(e1, counter_id, ecs.new("Counter", {count = 7})) ~= 0, "entity_set_component(counter) failed")
expect(ecs.entity_has_component(e1, counter_id) == true, "counter should be present after set")

local cptr = assert(ecs.entity_get_component(e1, counter_id, "Counter*"), "entity_get_component(counter) returned nil")
expect(cptr[0].count == 7, "expected counter==7")

-- Mark component as changed (should not crash)
ecs.entity_mark_component(e1, counter_id)

expect(ecs.entity_remove_component(e1, counter_id) ~= 0, "entity_remove_component(counter) failed")
expect(ecs.entity_has_component(e1, counter_id) == false, "counter should be absent after remove")
expect(ecs.entity_get_component(e1, counter_id, "Counter*") == nil, "get_component should return nil after remove")

print("test_components.lua: OK")
ecs.fini()
