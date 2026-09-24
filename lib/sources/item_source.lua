local flib_dictionary = require("__flib__.dictionary")
local FontColors = require("lib.font_colors")
local ItemCounts = require("lib.item_counts")
local LogisticsState = require("lib.logistics_state")
local NumberFormat = require("lib.number_format")
local rich_text = require("lib.rich_text")
local build_candidates = require("lib.sources.prototype_candidate")

local ItemSource = {}

-- Uses FontColors.MUTED so this can't drift from palette.lua's own style.font_color
-- of the same name.
local function muted(text)
  local color = FontColors.MUTED
  return ("[color=%d,%d,%d]%s[/color]"):format(color.r, color.g, color.b, text)
end

--- A count as it appears on a row, muted when it is zero.
---
--- Muting a zero rather than hiding it is the point: a candidate the player holds none
--- of still shows a 0, just one that doesn't visually compete with the rows they do
--- hold something of.
---@param value number
---@return string  rich text, so it carries its own color
function ItemSource.format_count(value)
  local text = NumberFormat.suffixed(value)
  if value == 0 then
    return muted(text)
  end
  return text
end

-- SEPARATOR is deliberately not "/": that reads as "current / max", which this isn't
-- -- inventory and network are two independent totals, not a fraction. Muted like the
-- counts that carry nothing: it is punctuation holding two figures apart, not a figure.
local SEPARATOR = "·"
-- Muted for the same reason a zero count is, only more so: this one says the number
-- can't be read at all, and -- unlike a zero, which varies per row -- it is the same
-- mark on every row while the player is out of range.
local OUT_OF_RANGE_TEXT = "—"

--- The row's headline count.
---
--- Just the inventory count while locked -- there is nothing to pair it with yet --
--- otherwise inventory, separator, network, with the network figure replaced by a
--- muted dash when the player is outside any network's range.
---@param state string  as LogisticsState.classify returns
---@param inventory_total number
---@param network_total number  ignored unless state is "connected"
---@return string  rich text
function ItemSource.build_caption(state, inventory_total, network_total)
  local inventory_text = ItemSource.format_count(inventory_total)
  if state == "locked" then
    return inventory_text
  end
  local network_text = state == "out_of_range" and muted(OUT_OF_RANGE_TEXT) or ItemSource.format_count(network_total)
  return inventory_text .. " " .. muted(SEPARATOR) .. " " .. network_text
end

-- Without the Quality mod, prototypes.quality has only "normal" (visible) and
-- "quality-unknown" (hidden, internal, confirmed over RCON to never appear on a real
-- item stack outside of an explicit scripted quality="quality-unknown" insert) -- so
-- an item's breakdown is always length 1 and this limit never applies. The Quality
-- mod alone brings it to 5 tiers; another mod could add more, so this still bounds
-- that case rather than assuming 5 is the ceiling.
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

--- The row's tooltip: the inventory line, plus network and in-transit lines once
--- connected.
---
--- delivering_total/picking_up_total are what robots currently carry to and from the
--- player -- not a shortfall -- and only mean anything once connected: a request can
--- be set while out of range (see LogisticsState.classify), but nothing can be in
--- transit until a network actually has the player in range.
---@param state string  as LogisticsState.classify returns
---@param inventory_total number
---@param inventory_breakdown table  as ItemCounts.breakdown returns; listed only
---  when it has more than one quality
---@param network_total number
---@param network_breakdown table
---@param delivering_total number|nil  omitted from the tooltip when nil or 0
---@param picking_up_total number|nil  omitted from the tooltip when nil or 0
---@return table  a LocalisedString
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

--- The candidate's annotation: the row caption and tooltip built from one set of
--- figures.
---
--- nil for no_character, since nothing about personal logistics is shown at all in
--- that state.
---@param state string  as LogisticsState.classify returns
---@param inventory_total number
---@param inventory_breakdown table
---@param network_total number
---@param network_breakdown table
---@param delivering_total number|nil
---@param picking_up_total number|nil
---@return table|nil  { caption, tooltip }; see EXTENDING.md "Candidates"
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

--- Annotates one candidate from a per-player context.
---
--- ctx holds everything per-player -- the logistics state and the merged count indexes
--- -- gathered once per search, which is what keeps this a function of the candidate
--- alone and spec-able without a Factorio runtime.
---@param candidate table  only its `id` is read
---@param ctx table  as gather_annotation_context builds it
---@return table|nil  { caption, tooltip }, or nil when there is nothing to show
function ItemSource.annotate(candidate, ctx)
  return ItemSource.build_annotation(
    ctx.state,
    ItemCounts.total(ctx.inventory_index, candidate.id),
    ItemCounts.breakdown(ctx.inventory_index, candidate.id, ctx.quality_order),
    ItemCounts.total(ctx.network_index, candidate.id),
    ItemCounts.breakdown(ctx.network_index, candidate.id, ctx.quality_order),
    ItemCounts.total(ctx.deliver_index, candidate.id),
    ItemCounts.total(ctx.pickup_index, candidate.id)
  )
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

--- Registers the item-name dictionary with flib, for translated-name search.
---
--- Must run from on_init/on_configuration_changed, before the first on_tick -- see
--- control.lua and EXTENDING.md "Translated names".
function ItemSource.register_dictionary()
  flib_dictionary.new(NAMESPACE)
  for _, item in ipairs(collect_items()) do
    flib_dictionary.add(NAMESPACE, item.name, item.localised_name)
  end
end

--- Builds this source's candidates for one query, before annotation.
---@param query string
---@param items table  array of item prototypes
---@param locale string|nil
---@param translated_names table  prototype name -> translated name
---@param include_hidden boolean
---@return table  candidates; see EXTENDING.md "Candidates"
function ItemSource.build_candidates(query, items, locale, translated_names, include_hidden)
  return build_candidates("item", "item", query, items, locale, translated_names, include_hidden)
end

-- Inventories counted toward the "inventory" total: main inventory, cursor stack,
-- ammo and guns (confirmed over RCON that character.get_item_count covers exactly
-- this set, but only for a single quality at a time, hence merging get_contents()
-- here instead). Deliberately excludes the trash slots: an item sitting there is
-- physically still on the character (not yet actually returned to the network), so
-- this is a known undercount for a player who's trashed something -- accepted
-- rather than also tracked via the character's separate trash logistic point.
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

-- {quality_name = tier_level}, for ItemCounts.breakdown's low-to-high tier sort.
-- Rebuilt on every call rather than cached at module scope: qualities can only
-- change between a data-stage reload, but nothing here is expensive enough
-- (Quality tops out at 5 tiers vanilla, low double digits with a mod like
-- More Quality Tiers) to be worth caching against that edge case.
local function quality_levels()
  local levels = {}
  for name, quality in pairs(prototypes.quality) do
    levels[name] = quality.level
  end
  return levels
end

-- Every per-player fact the annotation needs, read once per search rather than
-- per candidate. Returns nil when there is no character to report on at all.
local function gather_annotation_context(player)
  local character = player.character
  if character == nil then
    return nil
  end
  local requester_point = character.get_logistic_point(defines.logistic_member_index.character_requester)
  local ctx = {
    state = LogisticsState.classify(true, requester_point),
    inventory_index = personal_inventory_index(character),
    quality_order = quality_levels(),
    network_index = ItemCounts.merge({}),
    deliver_index = ItemCounts.merge({}),
    pickup_index = ItemCounts.merge({}),
  }
  if ctx.state == "connected" then
    ctx.network_index = ItemCounts.merge(requester_point.logistic_network.get_contents())
    ctx.deliver_index = ItemCounts.merge(requester_point.targeted_items_deliver)
    ctx.pickup_index = ItemCounts.merge(requester_point.targeted_items_pickup)
  end
  return ctx
end

-- Annotating every match rather than only the displayed ones is deliberate here:
-- the candidate carries its own annotation across the remote boundary, so there
-- is no later hook that could narrow the set first. The pcall keeps an
-- annotation failure from taking the result list down with it -- without it,
-- Palette.search_all_sources' own pcall would discard every candidate this
-- source found. Because this loop mutates candidates in place, a failure partway
-- leaves the earlier candidates annotated and the rest bare: a mixed render is
-- the accepted cost of not losing the results themselves.
local function apply_annotations(candidates, player)
  local ctx = gather_annotation_context(player)
  if ctx == nil then
    return
  end
  for _, candidate in ipairs(candidates) do
    candidate.annotation = ItemSource.annotate(candidate, ctx)
  end
end

local function search(query, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return {}
  end
  local include_hidden = player.mod_settings["quidquid-include-hidden"].value
  local translated_names = flib_dictionary.get(player_index, NAMESPACE) or {}
  local candidates =
    ItemSource.build_candidates(query, collect_items(), player.locale, translated_names, include_hidden)
  local ok, err = pcall(apply_annotations, candidates, player)
  if not ok then
    log(("quidquid: source 'items' annotation failed: %s"):format(tostring(err)))
  end
  return candidates
end

--- Adds this source's remote interface and registers it with Quidquid.
function ItemSource.register()
  remote.add_interface("quidquid.item-source", { search = search })
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
