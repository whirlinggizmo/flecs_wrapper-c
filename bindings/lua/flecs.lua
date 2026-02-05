local core = require("flecs_wrapper.bindings.lua.flecs_wrapper")

local helpers = {
  component = require("flecs_wrapper.bindings.lua.component"),
  entity = require("flecs_wrapper.bindings.lua.entity"),
  observer = require("flecs_wrapper.bindings.lua.observer"),
  system = require("flecs_wrapper.bindings.lua.system"),
  pair = require("flecs_wrapper.bindings.lua.pair"),
}

core.helpers = helpers

for k, v in pairs(helpers) do
  if core[k] == nil then
    core[k] = v
  end
end

return core
