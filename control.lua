-- control.lua
local Registry = require("lib.registry")
local ItemSource = require("lib.item_source")

local registry = Registry.new(log)

remote.add_interface("quidquid", {
  register_source = function(definition)
    return registry:register_source(definition)
  end,
  register_action = function(definition)
    return registry:register_action(definition)
  end,
})

ItemSource.register()

script.on_init(ItemSource.on_init)
script.on_configuration_changed(ItemSource.on_configuration_changed)
script.on_event(defines.events.on_player_joined_game, ItemSource.on_player_joined_game)
script.on_event(defines.events.on_player_locale_changed, ItemSource.on_player_locale_changed)
script.on_event(defines.events.on_player_left_game, ItemSource.on_player_left_game)
script.on_event(defines.events.on_string_translated, ItemSource.on_string_translated)
