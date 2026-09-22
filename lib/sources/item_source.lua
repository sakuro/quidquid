local flib_dictionary = require("__flib__.dictionary")
local build_candidates = require("lib.sources.prototype_candidate")

local ItemSource = {}

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
