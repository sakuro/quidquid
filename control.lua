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

-- remote.call is only valid inside an event, never at control.lua's top level (confirmed
-- in-game: "Attempt to remote call outside of an event"). Neither on_init (only fires for a
-- brand-new save) nor on_configuration_changed (only fires when something actually changed)
-- nor on_load (no game/remote API access at all) covers an ordinary continued load, so
-- ItemSource.register()'s remote.call runs on the first tick after any load instead.
script.on_event(defines.events.on_tick, function()
  script.on_event(defines.events.on_tick, nil)
  ItemSource.register()
end)

script.on_init(ItemSource.on_init)
script.on_configuration_changed(ItemSource.on_configuration_changed)
script.on_event(defines.events.on_player_joined_game, ItemSource.on_player_joined_game)
script.on_event(defines.events.on_player_locale_changed, ItemSource.on_player_locale_changed)
script.on_event(defines.events.on_player_left_game, ItemSource.on_player_left_game)
script.on_event(defines.events.on_string_translated, ItemSource.on_string_translated)
