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

--- Wires in the editor module, which control.lua passes after requiring both.
---
--- Injected rather than required here: the editor already requires this module, and
--- Factorio only allows `require` during control.lua's initial parsing, so a mutual
--- require cannot be resolved by deferring one side to call time.
---@param editor_module table  lib.temporary_request_editor
function TemporaryRequestAction.init(editor_module)
  editor = editor_module
end

-- Deliberately a plain string, not a LocalisedString: `find_section_index_by_group`
-- identifies this mod's section by exact string match, and LuaLogisticSection has no
-- other stable identifier. Localizing this per-locale would orphan existing sections
-- whenever a player's locale changed.
local GROUP = "[virtual-signal=signal-Q] Quidquid: Temporary requests"

--- The index of the section with that group name.
---@param existing_groups table  plain array of group-name strings, already extracted
---  from real sections by the caller
---@param group string
---@return number|nil
function TemporaryRequestAction.find_section_index_by_group(existing_groups, group)
  for i, g in ipairs(existing_groups) do
    if g == group then
      return i
    end
  end
  return nil
end

--- The slot already holding this item+quality, or the first free slot after the last
--- used one.
---@param existing table  plain array of slots, already extracted by the caller
---@param item_name string
---@param quality string
---@return number  always a usable index: one past the end when nothing matches
function TemporaryRequestAction.find_or_next_slot_index(existing, item_name, quality)
  for i, slot in ipairs(existing) do
    if slot.value ~= nil and slot.value.name == item_name and slot.value.quality == quality then
      return i
    end
  end
  return #existing + 1
end

--- The player's total requested count for one item+quality, across every section.
---
--- `filters` already reflects Factorio's own per-item pooled total across every section
--- on the point, so a single matching entry's `count` IS the combined target -- no
--- manual summation across sections is needed here.
---@param filters table  shaped like LuaLogisticPoint.filters: a plain array of
---  { name, quality, count }, already extracted by the caller
---@param item_name string
---@param quality string
---@return number  0 when the item is not requested at all
function TemporaryRequestAction.combined_target(filters, item_name, quality)
  for _, filter in ipairs(filters) do
    if filter.name == item_name and filter.quality == quality then
      return filter.count
    end
  end
  return 0
end

--- The player's character requester point, or nil when there is no character.
---
--- Also nil while force.character_logistic_requests is off, even in range -- see
--- LogisticsState.classify, which is why the character check is passed separately.
---@param player LuaPlayer
---@return LuaLogisticPoint|nil
function TemporaryRequestAction.requester_point_for(player)
  if player.character == nil then
    return nil
  end
  return player.character.get_logistic_point(defines.logistic_member_index.character_requester)
end

--- This mod's own logistic section on that point, without creating one.
---
--- For callers that only want to look at existing requests without side effects, such
--- as the editor prefilling its fields.
---@param point LuaLogisticPoint
---@return LuaLogisticSection|nil  nil when this player has no such section yet
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

--- This mod's own logistic section on that point, creating an empty one if needed.
---
--- Only for a caller about to write a slot; a read-only lookup uses
--- find_existing_section, which has no side effect.
---@param point LuaLogisticPoint
---@return LuaLogisticSection
function TemporaryRequestAction.get_or_create_section(point)
  local section = TemporaryRequestAction.find_existing_section(point)
  if section ~= nil then
    return section
  end
  return point.add_section(GROUP)
end

--- Decides whether selected_candidate has an item-shaped target to request.
---
--- Item candidates always do; a recipe candidate needs at least one item ingredient,
--- since a request naming only fluid ingredients doesn't make sense.
---
--- is_available only gates on player/logistics-network state, uniform across every
--- candidate; this per-candidate fact is resolved here and reported by execute rather
--- than hidden from the tooltip.
---@param selected_candidate table
---@param force LuaForce
---@return boolean
---@return string|nil  locale key explaining a false; nil for a recipe candidate with no
---  matching force recipe -- a near-impossible case not worth a message, since
---  RecipeSource builds candidates from prototypes.recipe directly
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

--- Whether this action is offered at all, for state uniform across every candidate.
---
--- Requests can be set both out of range and connected -- only no_character and locked
--- rule it out. See LogisticsState.classify for what distinguishes the four states.
---@param player_index uint
---@return boolean
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

--- Clears any temporary request the player has now satisfied.
---
--- This is what makes the request temporary: nothing else removes it. Registered from
--- control.lua, so it runs whether or not the palette is ever opened.
---@param event table  any of the five inventory/cursor events control.lua registers
function TemporaryRequestAction.on_inventory_changed(event)
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end
  check_and_clear(player)
end

--- Adds this action's remote interface and registers it with Quidquid.
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
