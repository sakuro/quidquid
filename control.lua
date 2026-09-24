local flib_dictionary = require("__flib__.dictionary")
local Registry = require("lib.registry")
local ItemSource = require("lib.sources.item_source")
local FluidSource = require("lib.sources.fluid_source")
local RecipeSource = require("lib.sources.recipe_source")
local TechnologySource = require("lib.sources.technology_source")
local SurfaceSource = require("lib.sources.surface_source")
local CalculatorSource = require("lib.sources.calculator_source")
local ResourceSource = require("lib.sources.resource_source")
local OpenRemoteViewAction = require("lib.actions.open_remote_view_action")
local OpenFactoriopediaAction = require("lib.actions.open_factoriopedia_action")
local OpenTechnologyAction = require("lib.actions.open_technology_action")
local ResearchQueueAction = require("lib.actions.research_queue_action")
local CraftAction = require("lib.actions.craft_action")
local PipetteAction = require("lib.actions.pipette_action")
local PinResourceAction = require("lib.actions.pin_resource_action")
local TemporaryRequestAction = require("lib.actions.temporary_request_action")
local TemporaryRequestEditor = require("lib.temporary_request_editor")
local Palette = require("lib.palette")
local api = require("lib.api")

local registry = Registry.new(log)

Palette.init(registry)
TemporaryRequestAction.init(TemporaryRequestEditor)

remote.add_interface("quidquid", {
  register_source = function(definition)
    return registry:register_source(definition)
  end,
  register_action = function(definition)
    local ok = registry:register_action(definition)
    if ok then
      script.on_event(definition.input_name, Palette.on_action_key)
    end
    return ok
  end,
})

local dictionary_sources = { ItemSource, FluidSource, RecipeSource, TechnologySource, SurfaceSource, ResourceSource }

-- flib_dictionary.new/.add may only run before flib's internal init_ran flag flips true,
-- which happens on the first on_tick -- so dictionaries must be (re-)registered from
-- on_init/on_configuration_changed, never deferred to on_tick like the remote.call
-- registrations below. Both of those already fully reset storage.__flib.dictionary
-- (flib_dictionary.on_configuration_changed is an alias for .on_init), so re-registering
-- unconditionally here is correct, not redundant.
local function register_dictionaries()
  for _, source in ipairs(dictionary_sources) do
    source.register_dictionary()
  end
end

script.on_init(function()
  flib_dictionary.on_init()
  register_dictionaries()
  ResourceSource.ensure_storage()
end)
script.on_configuration_changed(function()
  flib_dictionary.on_configuration_changed()
  register_dictionaries()
  ResourceSource.ensure_storage()
end)

-- remote.call is only valid inside an event, never at control.lua's top level (confirmed
-- in-game: "Attempt to remote call outside of an event"). Neither on_init (only fires for a
-- brand-new save) nor on_configuration_changed (only fires when something actually changed)
-- nor on_load (no game/remote API access at all) covers an ordinary continued load, so
-- each source/action's remote.call runs on the first tick after any load instead. The handler
-- itself stays registered, because flib_dictionary.on_tick has to run every tick to progress
-- translation batching; a flag gates the one-shot part.
local remote_interfaces_registered = false

script.on_event(defines.events.on_tick, function()
  if not remote_interfaces_registered then
    remote_interfaces_registered = true
    ItemSource.register()
    FluidSource.register()
    RecipeSource.register()
    TechnologySource.register()
    SurfaceSource.register()
    CalculatorSource.register()
    OpenRemoteViewAction.register()
    OpenFactoriopediaAction.register()
    OpenTechnologyAction.register()
    ResearchQueueAction.register()
    CraftAction.register()
    PipetteAction.register()
    PinResourceAction.register()
    TemporaryRequestAction.register()
    ResourceSource.register()
  end
  flib_dictionary.on_tick()
  ResourceSource.on_tick()
end)

script.on_event(defines.events.on_string_translated, flib_dictionary.on_string_translated)
script.on_event(defines.events.on_player_joined_game, flib_dictionary.on_player_joined_game)
script.on_event(defines.events.on_player_locale_changed, flib_dictionary.on_player_locale_changed)

script.on_event("quidquid-open-palette", Palette.on_open)
script.on_event("quidquid-palette-up", Palette.on_palette_up)
script.on_event("quidquid-palette-down", Palette.on_palette_down)

-- Palette and TemporaryRequestEditor each own a disjoint set of GUI elements and both
-- already no-op for events aimed at elements they don't recognize (checked by name/tag
-- at the top of each handler) — script.on_event only accepts one handler per event per
-- mod, so both are chained from a single registration rather than one silently
-- replacing the other.
script.on_event(defines.events.on_gui_text_changed, function(event)
  Palette.on_gui_text_changed(event)
  TemporaryRequestEditor.on_gui_text_changed(event)
end)
script.on_event(defines.events.on_gui_confirmed, Palette.on_gui_confirmed)
script.on_event(defines.events.on_gui_hover, Palette.on_gui_hover)
script.on_event(defines.events.on_gui_closed, function(event)
  Palette.on_gui_closed(event)
  TemporaryRequestEditor.on_gui_closed(event)
  local player = game.get_player(event.player_index)
  if player ~= nil then
    Palette.reclaim_opened(player)
  end
end)

script.on_event(defines.events.on_gui_click, function(event)
  Palette.on_gui_click(event)
  TemporaryRequestEditor.on_gui_click(event)
  TemporaryRequestEditor.on_cancel_button(event)
end)
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

-- SurfaceSource's cached search keys are keyed by surface name; evict them alongside
-- the position history above so a destroyed surface's cache doesn't linger for the
-- rest of the session. on_pre_surface_deleted only gives surface_index, so the surface
-- (still valid -- this fires just before deletion) is looked up to get its name.
script.on_event(defines.events.on_pre_surface_deleted, function(event)
  OpenRemoteViewAction.on_pre_surface_deleted(event)
  local surface = game.get_surface(event.surface_index)
  if surface ~= nil then
    api.forget("surface", surface.name)
  end
  ResourceSource.on_surface_removed(event)
end)

-- Palette also keys a small per-player table (pin state) by player_index, which needs
-- the same reused-index cleanup as OpenRemoteViewAction's history above.
script.on_event(defines.events.on_player_removed, function(event)
  OpenRemoteViewAction.on_player_removed(event)
  Palette.on_player_removed(event)
end)

-- The resource cluster cache is derived from the world, so every event that changes
-- which resources exist, or which chunks hold them, has to reach it. There is no event
-- for un-charting: LuaForce.clear_chart raises nothing, so visibility is filtered per
-- force at search time rather than tracked here.
script.on_event(defines.events.on_chunk_charted, ResourceSource.on_chunk_charted)
script.on_event(defines.events.on_chunk_deleted, ResourceSource.on_chunk_deleted)
script.on_event(defines.events.on_surface_cleared, ResourceSource.on_surface_removed)
script.on_event(defines.events.on_surface_deleted, ResourceSource.on_surface_removed)
script.on_event(defines.events.on_resource_depleted, ResourceSource.on_resource_depleted)

-- LuaBootstrap.on_event's filters parameter only applies "when registering for
-- individual events" (confirmed against runtime-api.json and empirically: passing it
-- alongside an array of events raises "Filters can only be used when registering single
-- non custom-input events"), so the same filter is repeated across four registrations
-- rather than one call with an event array. Addition and removal share a handler because
-- both boil down to the same correction: re-enqueue the chunk and let the background
-- scan recompute it from what is actually there now.
local RESOURCE_ENTITY_FILTER = { { filter = "type", type = "resource" } }
script.on_event(defines.events.on_built_entity, ResourceSource.on_resource_entity_changed, RESOURCE_ENTITY_FILTER)
script.on_event(defines.events.on_robot_built_entity, ResourceSource.on_resource_entity_changed, RESOURCE_ENTITY_FILTER)
script.on_event(defines.events.script_raised_built, ResourceSource.on_resource_entity_changed, RESOURCE_ENTITY_FILTER)
script.on_event(defines.events.script_raised_destroy, ResourceSource.on_resource_entity_changed, RESOURCE_ENTITY_FILTER)
