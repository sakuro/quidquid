-- lib/actions/temporary_request_action.lua
local TemporaryRequestAction = {}

-- Deliberately a plain string, not a LocalisedString: `find_section_index_by_group`
-- identifies this mod's section by exact string match, and LuaLogisticSection has no
-- other stable identifier. Localizing this per-locale would orphan existing sections
-- whenever a player's locale changed.
local GROUP = "[virtual-signal=signal-Q] Quidquid: Temporary requests"

-- pure, testable: `existing_groups` is a plain array of group-name strings already
-- extracted from real sections by the caller
function TemporaryRequestAction.find_section_index_by_group(existing_groups, group)
  for i, g in ipairs(existing_groups) do
    if g == group then
      return i
    end
  end
  return nil
end

-- pure, testable: `existing` is a plain array already extracted from real slots by the caller
function TemporaryRequestAction.find_slot_index(existing, item_name, quality)
  for i, slot in ipairs(existing) do
    if slot.value ~= nil and slot.value.name == item_name and slot.value.quality == quality then
      return i
    end
  end
  return #existing + 1
end

-- pure, testable: `filters` is shaped like `LuaLogisticPoint.filters` (a plain array of
-- {name=.., quality=.., count=..} tables), already extracted by the caller. `filters`
-- already reflects Factorio's own per-item pooled total across every section on the
-- point, so a single matching entry's `count` IS the combined target -- no manual
-- summation across sections is needed here.
function TemporaryRequestAction.combined_target(filters, item_name, quality)
  for _, filter in ipairs(filters) do
    if filter.name == item_name and filter.quality == quality then
      return filter.count
    end
  end
  return 0
end

function TemporaryRequestAction.logistic_point_for(player)
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

local function is_applicable(_selected_candidate, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return false
  end
  return TemporaryRequestAction.logistic_point_for(player) ~= nil
end

local function execute(selected_candidate, _params, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return
  end
  -- Required lazily (not at module top) because temporary_request_editor.lua requires this
  -- module back, to use its public section/slot helpers -- a top-level require on both sides
  -- would deadlock in Lua's module loader (package.loaded isn't set until a chunk finishes
  -- running, so mutual top-level requires recurse until the C stack is exhausted).
  local TemporaryRequestEditor = require("lib.temporary_request_editor")
  TemporaryRequestEditor.open(player, selected_candidate.id)
end

local function check_and_clear(player)
  local point = TemporaryRequestAction.logistic_point_for(player)
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
    is_applicable = is_applicable,
    execute = execute,
  })
  remote.call("quidquid", "register_action", {
    version = 1,
    id = "temporary-request",
    types = {"item"},
    label = {"quidquid.action-temporary-request"},
    key = "quidquid-temporary-request",
    interface = "quidquid.temporary-request-action",
  })
end

return TemporaryRequestAction
