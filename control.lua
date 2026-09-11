-- control.lua
local Registry = require("lib.registry")

local registry = Registry.new(log)

remote.add_interface("quidquid", {
  register_source = function(definition)
    return registry:register_source(definition)
  end,
  register_action = function(definition)
    return registry:register_action(definition)
  end,
})
