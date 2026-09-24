local ActionRunner = require("lib.action_runner")
local LogisticsState = require("lib.logistics_state")

local TemporaryRequestAction = {}

-- Injected from control.lua (see TemporaryRequestAction.init) rather than required
-- directly: lib/temporary_request_editor.lua already requires this module (to reuse its
-- section/slot helpers), and Factorio only allows `require` during control.lua's initial
-- parsing, not later from inside an event handler like `execute` -- so a mutual
-- require between the two files isn't resolvable by deferring one side to call time
-- (confirmed in-game: "Require can't be used outside of control.lua parsing."). Both
-- modules are required once, up front, in control.lua, which then wires this one in.
local editor = nil

function TemporaryRequestAction.init(editor_module)
  editor = editor_module
end

-- Deliberately a plain string, not a LocalisedString: `find_section_index_by_group`
-- identifies this mod's section by exact string match, and LuaLogisticSection has no
-- other stable identifier. Localizing this per-locale would orphan existing sections
-- whenever a player's locale changed.
local GROUP = "[virtual-signal=signal-Q] Quidquid: Temporary requests"

-- `existing_groups` is a plain array of group-name strings already extracted from real
-- sections by the caller
function TemporaryRequestAction.find_section_index_by_group(existing_groups, group)
  for i, g in ipairs(existing_groups) do
    if g == group then
      return i
    end
  end
  return nil
end

-- `existing` is a plain array already extracted from real slots by the caller
function TemporaryRequestAction.find_or_next_slot_index(existing, item_name, quality)
  for i, slot in ipairs(existing) do
    if slot.value ~= nil and slot.value.name == item_name and slot.value.quality == quality then
      return i
    end
  end
  return #existing + 1
end

-- `filters` is shaped like `LuaLogisticPoint.filters` (a plain array of {name=..,
-- quality=.., count=..} tables), already extracted by the caller. `filters` already
-- reflects Factorio's own per-item pooled total across every section on the point, so
-- a single matching entry's `count` IS the combined target -- no manual summation
-- across sections is needed here.
function TemporaryRequestAction.combined_target(filters, item_name, quality)
  for _, filter in ipairs(filters) do
    if filter.name == item_name and filter.quality == quality then
      return filter.count
    end
  end
  return 0
end

function TemporaryRequestAction.requester_point_for(player)
  if player.character == nil then
    return nil
  end
  return player.character.get_logistic_point(defines.logistic_member_index.character_requester)
end

-- Returns the shared section, or nil if it doesn't exist yet for this player -- unlike
-- get_or_create_section, never creates one. Used by callers that only want to look at
-- existing requests without side effects (e.g. the editor prefilling its fields).
function TemporaryRequestAction.find_existing_section(point)
  local groups = {}
  for i = 1, point.sections_count do
    groups[i] = point.sections[i].group
  end
  local index = TemporaryRequestAction.find_section_index_by_group(groups, GROUP)
  if index == nil then
    return nil
  end
  return point.sections[index]
end

-- Creates an empty section as a side effect if none exists yet -- only call this when
-- about to write a slot. Use find_existing_section for read-only lookups (e.g. prefill).
function TemporaryRequestAction.get_or_create_section(point)
  local section = TemporaryRequestAction.find_existing_section(point)
  if section ~= nil then
    return section
  end
  return point.add_section(GROUP)
end

-- Decides whether selected_candidate has an item-shaped target to request. Item
-- candidates always do; recipe candidates need at least one item ingredient (a request
-- naming only fluid ingredients doesn't make sense). Returns true, or false plus a
-- locale key explaining why not (nil for a recipe candidate with no matching force
-- recipe -- a near-impossible case not worth a message, since RecipeSource builds
-- candidates from prototypes.recipe directly).
-- is_available only gates on player/logistics-network state, uniform across every
-- candidate; this per-candidate fact is resolved here and reported by execute
-- instead, not hidden from the tooltip.
function TemporaryRequestAction.resolve_requestable(selected_candidate, force)
  if selected_candidate.type ~= "recipe" then
    return true, nil
  end
  local recipe = force.recipes[selected_candidate.id]
  if recipe == nil then
    return false, nil
  end
  for _, ingredient in ipairs(recipe.ingredients) do
    if ingredient.type == "item" then
      return true, nil
    end
  end
  return false, "quidquid.action-recipe-temporary-request-no-item-ingredients"
end

-- Requests can be set both out of range and connected -- only no_character and
-- locked rule it out. See LogisticsState.classify for what distinguishes the four
-- states.
function TemporaryRequestAction.is_available(player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return false
  end
  local state = LogisticsState.classify(player.character ~= nil, TemporaryRequestAction.requester_point_for(player))
  return state == "out_of_range" or state == "connected"
end

-- Adapts the boolean resolve_requestable to ActionRunner's nil/payload
-- convention: the candidate itself is the payload, since editor.open needs
-- nothing beyond what it already has.
local function resolve(selected_candidate, player)
  local requestable, reason_locale_key = TemporaryRequestAction.resolve_requestable(selected_candidate, player.force)
  if not requestable then
    return nil, reason_locale_key
  end
  return selected_candidate, nil
end

local function execute(selected_candidate, player_index)
  ActionRunner.run(selected_candidate, player_index, resolve, function(candidate, _candidate, player)
    editor.open(player, candidate)
  end)
end

local function check_and_clear(player)
  local point = TemporaryRequestAction.requester_point_for(player)
  if point == nil then
    return
  end
  local section = TemporaryRequestAction.find_existing_section(point)
  if section == nil then
    return
  end

  local filters = point.filters
  for i = 1, section.filters_count do
    local slot = section.get_slot(i)
    if slot.value ~= nil then
      local target = TemporaryRequestAction.combined_target(filters, slot.value.name, slot.value.quality)
      local count = player.character.get_item_count({ name = slot.value.name, quality = slot.value.quality })
      if count >= target then
        section.clear_slot(i)
      end
    end
  end
end

function TemporaryRequestAction.on_inventory_changed(event)
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end
  check_and_clear(player)
end

function TemporaryRequestAction.register()
  remote.add_interface("quidquid.temporary-request-action", {
    is_available = TemporaryRequestAction.is_available,
    execute = execute,
  })
  remote.call("quidquid", "register_action", {
    contract_version = 1,
    id = "temporary-request",
    types = { "item", "recipe" },
    label = { "quidquid.action-temporary-request" },
    input_name = "quidquid-temporary-request",
    interface = "quidquid.temporary-request-action",
  })
end

return TemporaryRequestAction
