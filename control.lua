-- control.lua
local Registry = require("lib.registry")
local ItemSource = require("lib.sources.item_source")
local FluidSource = require("lib.sources.fluid_source")
local RecipeSource = require("lib.sources.recipe_source")
local TechnologySource = require("lib.sources.technology_source")
local SurfaceSource = require("lib.sources.surface_source")
local OpenRemoteViewAction = require("lib.actions.open_remote_view_action")
local OpenFactoriopediaAction = require("lib.actions.open_factoriopedia_action")
local OpenTechnologyAction = require("lib.actions.open_technology_action")
local ResearchQueueAction = require("lib.actions.research_queue_action")
local CraftAction = require("lib.actions.craft_action")
local TemporaryRequestAction = require("lib.actions.temporary_request_action")
local TemporaryRequestEditor = require("lib.temporary_request_editor")
local Palette = require("lib.palette")

local registry = Registry.new(log)

Palette.init(registry)
TemporaryRequestAction.init(TemporaryRequestEditor)

-- These custom-input names are quidquid's own hotkeys, wired to fixed handlers below.
-- script.on_event has last-registration-wins, no-stacking semantics, so an action that
-- registered under one of these keys would silently steal the event and break the hotkey.
local RESERVED_ACTION_KEYS = {
  ["quidquid-toggle"] = true,
  ["quidquid-clear-source-lock"] = true,
  ["quidquid-toggle-palette-pin"] = true,
  ["quidquid-cancel-button"] = true,
}

remote.add_interface("quidquid", {
  register_source = function(definition)
    return registry:register_source(definition)
  end,
  register_action = function(definition)
    if RESERVED_ACTION_KEYS[definition.key] then
      log(
        ("quidquid: action '%s' rejected: key '%s' is reserved for quidquid's own hotkeys"):format(
          tostring(definition.id),
          tostring(definition.key)
        )
      )
      return false
    end

    local ok = registry:register_action(definition)
    if ok then
      script.on_event(definition.key, Palette.on_action_key)
    end
    return ok
  end,
})

-- remote.call is only valid inside an event, never at control.lua's top level (confirmed
-- in-game: "Attempt to remote call outside of an event"). Neither on_init (only fires for a
-- brand-new save) nor on_configuration_changed (only fires when something actually changed)
-- nor on_load (no game/remote API access at all) covers an ordinary continued load, so
-- each source/action's remote.call runs on the first tick after any load instead.
script.on_event(defines.events.on_tick, function()
  script.on_event(defines.events.on_tick, nil)
  ItemSource.register()
  FluidSource.register()
  RecipeSource.register()
  TechnologySource.register()
  SurfaceSource.register()
  OpenRemoteViewAction.register()
  OpenFactoriopediaAction.register()
  OpenTechnologyAction.register()
  ResearchQueueAction.register()
  CraftAction.register()
  TemporaryRequestAction.register()
end)

-- All translated sources need these lifecycle events, but each of
-- script.on_init/on_configuration_changed/on_event accepts only one handler per event for the
-- whole mod (no stacking) — so a single dispatcher fans each event out to every source.
local translated_sources = { ItemSource, FluidSource, RecipeSource, TechnologySource, SurfaceSource }

local function for_each_translated_source(method_name)
  return function(event)
    for _, source in ipairs(translated_sources) do
      source[method_name](event)
    end
  end
end

script.on_init(for_each_translated_source("on_init"))
script.on_configuration_changed(for_each_translated_source("on_configuration_changed"))
script.on_event(defines.events.on_player_joined_game, for_each_translated_source("on_player_joined_game"))
script.on_event(defines.events.on_player_locale_changed, for_each_translated_source("on_player_locale_changed"))
script.on_event(defines.events.on_player_left_game, for_each_translated_source("on_player_left_game"))
script.on_event(defines.events.on_string_translated, for_each_translated_source("on_string_translated"))

script.on_event("quidquid-toggle", Palette.on_toggle)
script.on_event("quidquid-clear-source-lock", Palette.on_clear_source_lock)
script.on_event("quidquid-toggle-palette-pin", Palette.on_toggle_pin)
script.on_event("quidquid-cancel-button", function(event)
  Palette.on_cancel_button(event)
  TemporaryRequestEditor.on_cancel_button(event)
end)

-- Palette and TemporaryRequestEditor each own a disjoint set of GUI elements and both
-- already no-op for events aimed at elements they don't recognize (checked by name/tag
-- at the top of each handler) — script.on_event only accepts one handler per event per
-- mod, so both are chained from a single registration rather than one silently
-- replacing the other.
script.on_event(defines.events.on_gui_text_changed, function(event)
  Palette.on_gui_text_changed(event)
  TemporaryRequestEditor.on_gui_text_changed(event)
end)
script.on_event(defines.events.on_gui_closed, function(event)
  Palette.on_gui_closed(event)
  TemporaryRequestEditor.on_gui_closed(event)
  local player = game.get_player(event.player_index)
  if player ~= nil then
    Palette.reclaim_opened(player)
  end
end)

script.on_event(defines.events.on_gui_click, TemporaryRequestEditor.on_gui_click)
script.on_event(defines.events.on_gui_checked_state_changed, TemporaryRequestEditor.on_gui_checked_state_changed)
script.on_event("quidquid-temporary-request-editor-confirm", TemporaryRequestEditor.on_confirm_key)

-- Every event that can change what LuaControl:get_item_count sees for a player's
-- character — confirmed empirically that get_item_count aggregates across all of these
-- (main inventory, cursor stack, guns, ammo), so a temporary request can become
-- satisfied via any one of them.
script.on_event({
  defines.events.on_player_main_inventory_changed,
  defines.events.on_player_ammo_inventory_changed,
  defines.events.on_player_armor_inventory_changed,
  defines.events.on_player_gun_inventory_changed,
  defines.events.on_player_cursor_stack_changed,
}, TemporaryRequestAction.on_inventory_changed)

-- Track viewed tile positions for surface navigation; discard references when their
-- player or surface is removed so reused indices cannot inherit old positions.
script.on_event(defines.events.on_player_changed_position, OpenRemoteViewAction.on_player_changed_position)
script.on_event(defines.events.on_pre_surface_deleted, OpenRemoteViewAction.on_pre_surface_deleted)

-- Palette also keys a small per-player table (pin state) by player_index, which needs
-- the same reused-index cleanup as OpenRemoteViewAction's history above.
script.on_event(defines.events.on_player_removed, function(event)
  OpenRemoteViewAction.on_player_removed(event)
  Palette.on_player_removed(event)
end)
