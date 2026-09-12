local TranslatedPrototypeSource = require("lib.translated_prototype_source")
local build_candidates = require("lib.prototype_candidate")

local ItemSource = {}

local SOURCE_LABEL = {"quidquid.source-items"}

local function collect_items()
  local items = {}
  for _, item in pairs(prototypes.item) do
    table.insert(items, item)
  end
  return items
end

local translation = TranslatedPrototypeSource.new("items", collect_items, SOURCE_LABEL)

function ItemSource.build_candidates(query, items, locale, translation_cache, include_hidden)
  return build_candidates("item", "item", query, items, locale, translation_cache, include_hidden)
end

function ItemSource.on_string_translated(event)
  translation:on_string_translated(event)
end

function ItemSource.on_player_joined_game(event)
  translation:on_player_joined_game(event)
end

ItemSource.on_player_locale_changed = ItemSource.on_player_joined_game

function ItemSource.on_player_left_game(event)
  translation:on_player_left_game(event)
end

function ItemSource.on_init()
  translation:on_init()
end

function ItemSource.on_configuration_changed()
  translation:on_configuration_changed()
end

local function search(query, player_index, _context)
  local player = game.get_player(player_index)
  if player == nil then
    return {}
  end
  local include_hidden = player.mod_settings["quidquid-include-hidden"].value
  return ItemSource.build_candidates(query, collect_items(), player.locale, translation, include_hidden)
end

function ItemSource.register()
  remote.add_interface("quidquid.item-source", { search = search })
  remote.call("quidquid", "register_source", {
    version = 1,
    id = "items",
    type = "item",
    label = SOURCE_LABEL,
    prefixes = {"i", "item"},
    default_active = true,
    interface = "quidquid.item-source",
  })
end

return ItemSource
