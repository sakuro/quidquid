local flib_dictionary = require("__flib__.dictionary")
local Declarations = require("lib.declarations")
local Registry = require("lib.registry")
local ItemSource = require("lib.sources.item_source")
local FluidSource = require("lib.sources.fluid_source")
local RecipeSource = require("lib.sources.recipe_source")
local TechnologySource = require("lib.sources.technology_source")
local SurfaceSource = require("lib.sources.surface_source")
local CalculatorSource = require("lib.sources.calculator_source")
local OpenRemoteViewAction = require("lib.actions.open_remote_view_action")
local OpenFactoriopediaAction = require("lib.actions.open_factoriopedia_action")
local OpenTechnologyAction = require("lib.actions.open_technology_action")
local ResearchQueueAction = require("lib.actions.research_queue_action")
local CraftAction = require("lib.actions.craft_action")
local PipetteAction = require("lib.actions.pipette_action")
local TemporaryRequestAction = require("lib.actions.temporary_request_action")
local TemporaryRequestEditor = require("lib.temporary_request_editor")
local Palette = require("lib.palette")
local api = require("lib.api")

local registry = Registry.new(log)

Palette.init(registry)
TemporaryRequestAction.init(TemporaryRequestEditor)

-- Registration order decides score ties and first-come prefixes and action slots;
-- Declarations.collect fixes it by each prototype's order, then name.
for _, definition in ipairs(Declarations.collect(prototypes.mod_data, Declarations.SOURCE_DATA_TYPE)) do
  registry:register_source(definition)
end
for _, definition in ipairs(Declarations.collect(prototypes.mod_data, Declarations.ACTION_DATA_TYPE)) do
  if registry:register_action(definition) then
    script.on_event(definition.input_name, Palette.on_action_key)
  end
end

ItemSource.add_interface()
FluidSource.add_interface()
RecipeSource.add_interface()
TechnologySource.add_interface()
SurfaceSource.add_interface()
CalculatorSource.add_interface()
OpenRemoteViewAction.add_interface()
OpenFactoriopediaAction.add_interface()
OpenTechnologyAction.add_interface()
ResearchQueueAction.add_interface()
CraftAction.add_interface()
PipetteAction.add_interface()
TemporaryRequestAction.add_interface()

local dictionary_sources = { ItemSource, FluidSource, RecipeSource, TechnologySource, SurfaceSource }

-- flib_dictionary.new/.add may only run before flib's internal init_ran flag flips true,
-- which happens on the first on_tick -- so dictionaries must be (re-)registered from
-- on_init/on_configuration_changed. Both of those already fully reset
-- storage.__flib.dictionary (flib_dictionary.on_configuration_changed is an alias for
-- .on_init), so re-registering unconditionally here is correct, not redundant.
local function register_dictionaries()
  for _, source in ipairs(dictionary_sources) do
    source.register_dictionary()
  end
end

script.on_init(function()
  flib_dictionary.on_init()
  register_dictionaries()
end)

-- 0.8.0 owned a blueprint export window (screen frame
-- "quidquid-blueprint-export-frame"); now that the feature moved to
-- quidquid-blueprints, a save that kept that window open across the upgrade
-- has it stuck on screen with nothing left to handle its buttons.
local function destroy_stale_blueprint_export_frames()
  for _, player in pairs(game.players) do
    local frame = player.gui.screen["quidquid-blueprint-export-frame"]
    if frame ~= nil and frame.valid then
      frame.destroy()
    end
  end
end

script.on_configuration_changed(function()
  flib_dictionary.on_configuration_changed()
  register_dictionaries()
  destroy_stale_blueprint_export_frames()
  -- Resource search moved to quidquid-resources, which keeps its own cache; this one
  -- would only sit in the save.
  storage.resources = nil
end)

script.on_event(defines.events.on_tick, function()
  flib_dictionary.on_tick()
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
  -- A titlebar close button (the editor's cancel) destroys its frame directly
  -- rather than raising on_gui_closed, so the on_gui_closed handler's reclaim
  -- never runs for that path; check here too.
  local player = game.get_player(event.player_index)
  if player ~= nil then
    Palette.reclaim_opened(player)
  end
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
end)

-- Palette also keys a small per-player table (pin state) by player_index, which needs
-- the same reused-index cleanup as OpenRemoteViewAction's history above.
script.on_event(defines.events.on_player_removed, function(event)
  OpenRemoteViewAction.on_player_removed(event)
  Palette.on_player_removed(event)
end)
