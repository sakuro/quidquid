local flib_dictionary = require("__flib__.dictionary")
local FontColors = require("lib.font_colors")
local ItemCounts = require("lib.item_counts")
local LogisticsState = require("lib.logistics_state")
local NumberFormat = require("lib.number_format")
local rich_text = require("lib.rich_text")
local build_candidates = require("lib.sources.prototype_candidate")

local ItemSource = {}

-- Muting a zero count, rather than hiding it, is #121's whole point: a candidate the
-- player holds none of still shows a 0, just one that doesn't visually compete with
-- ones they do. Uses FontColors.MUTED so this can't drift from palette.lua's own
-- style.font_color of the same name.
function ItemSource.format_count(value)
  local text = NumberFormat.suffixed(value)
  if value == 0 then
    local muted = FontColors.MUTED
    return ("[color=%d,%d,%d]%s[/color]"):format(muted.r, muted.g, muted.b, text)
  end
  return text
end

-- SEPARATOR is deliberately not "/": that reads as "current / max", which this isn't
-- -- inventory and network are two independent totals, not a fraction.
local SEPARATOR = "·"
local OUT_OF_RANGE_TEXT = "—"

-- The row's headline: just the inventory count while locked (there's nothing to pair
-- it with yet), otherwise inventory SEPARATOR network, with network replaced by an
-- em dash when the player is outside any network's range.
function ItemSource.build_caption(state, inventory_total, network_total)
  local inventory_text = ItemSource.format_count(inventory_total)
  if state == "locked" then
    return inventory_text
  end
  local network_text = state == "out_of_range" and OUT_OF_RANGE_TEXT or ItemSource.format_count(network_total)
  return inventory_text .. " " .. SEPARATOR .. " " .. network_text
end

-- Vanilla plus the Quality mod tops out at 5 qualities; a mod could add more, so this
-- still bounds the pathological case rather than assuming it never happens.
local MAX_LISTED_QUALITIES = 5

local function quality_icon(entry)
  return ("[quality=%s]%s"):format(entry.quality, NumberFormat.suffixed(entry.count))
end

-- One labelled tooltip line, e.g. "Inventory: 45", with a per-quality breakdown
-- parenthesized after it once there's more than one quality to distinguish --
-- a single quality would just repeat the same total a second time.
local function count_line(label_key, total, breakdown)
  local line = { label_key, ItemSource.format_count(total) }
  if #breakdown <= 1 then
    return line
  end
  local list =
    rich_text.icon_list_caption(breakdown, quality_icon, MAX_LISTED_QUALITIES, "quidquid.item-counts-quality-list-more")
  return { "", line, " (", list, ")" }
end

-- delivering_total/picking_up_total are what robots currently carry to/from the
-- player -- not a shortfall -- and only mean anything once connected; a request
-- can be set while out of range (see LogisticsState.classify), but nothing can be
-- in transit until a network actually has the player in range.
function ItemSource.build_tooltip(
  state,
  inventory_total,
  inventory_breakdown,
  network_total,
  network_breakdown,
  delivering_total,
  picking_up_total
)
  local tooltip = { "", count_line("quidquid.item-counts-inventory", inventory_total, inventory_breakdown) }
  if state == "out_of_range" then
    table.insert(tooltip, "\n")
    table.insert(tooltip, { "gui.not-in-logistic-network" })
  elseif state == "connected" then
    table.insert(tooltip, "\n")
    table.insert(tooltip, count_line("quidquid.item-counts-network", network_total, network_breakdown))
    if delivering_total ~= nil and delivering_total > 0 then
      table.insert(tooltip, "\n")
      table.insert(tooltip, { "quidquid.item-counts-delivering", ItemSource.format_count(delivering_total) })
    end
    if picking_up_total ~= nil and picking_up_total > 0 then
      table.insert(tooltip, "\n")
      table.insert(tooltip, { "quidquid.item-counts-picking-up", ItemSource.format_count(picking_up_total) })
    end
  end
  return tooltip
end

-- The per-candidate result an `annotate` call returns (see #121): nil for
-- no_character, since nothing about personal logistics is shown at all in that
-- state; otherwise the row caption and tooltip built from the same figures.
function ItemSource.build_annotation(
  state,
  inventory_total,
  inventory_breakdown,
  network_total,
  network_breakdown,
  delivering_total,
  picking_up_total
)
  if state == "no_character" then
    return nil
  end
  return {
    caption = ItemSource.build_caption(state, inventory_total, network_total),
    tooltip = ItemSource.build_tooltip(
      state,
      inventory_total,
      inventory_breakdown,
      network_total,
      network_breakdown,
      delivering_total,
      picking_up_total
    ),
  }
end

local SOURCE_LABEL = { "quidquid.source-items" }
local NAMESPACE = "items"

local function collect_items()
  local items = {}
  for _, item in pairs(prototypes.item) do
    table.insert(items, item)
  end
  return items
end

function ItemSource.register_dictionary()
  flib_dictionary.new(NAMESPACE)
  for _, item in ipairs(collect_items()) do
    flib_dictionary.add(NAMESPACE, item.name, item.localised_name)
  end
end

function ItemSource.build_candidates(query, items, locale, translated_names, include_hidden)
  return build_candidates("item", "item", query, items, locale, translated_names, include_hidden)
end

local function search(query, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return {}
  end
  local include_hidden = player.mod_settings["quidquid-include-hidden"].value
  local translated_names = flib_dictionary.get(player_index, NAMESPACE) or {}
  return ItemSource.build_candidates(query, collect_items(), player.locale, translated_names, include_hidden)
end

-- Inventories counted toward the "inventory" total: main inventory, cursor stack,
-- ammo and guns -- the same scope QuickItemSearch used (confirmed over RCON that
-- character.get_item_count covers exactly this set, but only for a single quality
-- at a time, hence merging get_contents() here instead). Deliberately excludes the
-- trash slots: those hold items already released back to the network, not items
-- the player still has.
local function personal_inventory_index(character)
  local contents_lists = { character.get_main_inventory().get_contents() }
  local cursor_stack = character.cursor_stack
  if cursor_stack ~= nil and cursor_stack.valid_for_read then
    table.insert(
      contents_lists,
      { { name = cursor_stack.name, quality = cursor_stack.quality.name, count = cursor_stack.count } }
    )
  end
  for _, inventory_def in ipairs({ defines.inventory.character_ammo, defines.inventory.character_guns }) do
    local inventory = character.get_inventory(inventory_def)
    if inventory ~= nil then
      table.insert(contents_lists, inventory.get_contents())
    end
  end
  return ItemCounts.merge(table.unpack(contents_lists))
end

-- Called once per render with only the displayed item candidates (see
-- Palette.annotate_candidates), so every per-player fact below (state, the
-- inventory/network/delivery indexes) is gathered once here rather than per
-- candidate.
local function annotate(candidates, player_index)
  local player = game.get_player(player_index)
  if player == nil or player.character == nil then
    return {}
  end
  local character = player.character
  local requester_point = character.get_logistic_point(defines.logistic_member_index.character_requester)
  local state = LogisticsState.classify(true, requester_point)

  local inventory_index = personal_inventory_index(character)

  local network_index = ItemCounts.merge({})
  local deliver_index = ItemCounts.merge({})
  local pickup_index = ItemCounts.merge({})
  if state == "connected" then
    network_index = ItemCounts.merge(requester_point.logistic_network.get_contents())
    deliver_index = ItemCounts.merge(requester_point.targeted_items_deliver)
    pickup_index = ItemCounts.merge(requester_point.targeted_items_pickup)
  end

  local annotations = {}
  for index, candidate in ipairs(candidates) do
    annotations[index] = ItemSource.build_annotation(
      state,
      ItemCounts.total(inventory_index, candidate.id),
      ItemCounts.breakdown(inventory_index, candidate.id),
      ItemCounts.total(network_index, candidate.id),
      ItemCounts.breakdown(network_index, candidate.id),
      ItemCounts.total(deliver_index, candidate.id),
      ItemCounts.total(pickup_index, candidate.id)
    )
  end
  return annotations
end

function ItemSource.register()
  remote.add_interface("quidquid.item-source", { search = search, annotate = annotate })
  remote.call("quidquid", "register_source", {
    contract_version = 1,
    id = "items",
    type = "item",
    label = SOURCE_LABEL,
    prefixes = { "i", "item" },
    in_default_search = true,
    interface = "quidquid.item-source",
  })
end

return ItemSource
