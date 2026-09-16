local TranslatedPrototypeSource = require("lib.sources.translated_prototype_source")
local build_candidates = require("lib.sources.prototype_candidate")

local FluidSource = {}

local SOURCE_LABEL = { "quidquid.source-fluids" }

local function collect_fluids()
  local fluids = {}
  for _, fluid in pairs(prototypes.fluid) do
    table.insert(fluids, fluid)
  end
  return fluids
end

local translation = TranslatedPrototypeSource.new("fluids", collect_fluids, SOURCE_LABEL)

function FluidSource.build_candidates(query, fluids, locale, translation_cache, include_hidden)
  return build_candidates("fluid", "fluid", query, fluids, locale, translation_cache, include_hidden)
end

function FluidSource.on_string_translated(event)
  translation:on_string_translated(event)
end

function FluidSource.on_player_joined_game(event)
  translation:on_player_joined_game(event)
end

FluidSource.on_player_locale_changed = FluidSource.on_player_joined_game

function FluidSource.on_player_left_game(event)
  translation:on_player_left_game(event)
end

function FluidSource.on_init()
  translation:on_init()
end

function FluidSource.on_configuration_changed()
  translation:on_configuration_changed()
end

local function search(query, player_index, _context)
  local player = game.get_player(player_index)
  if player == nil then
    return {}
  end
  local include_hidden = player.mod_settings["quidquid-include-hidden"].value
  return FluidSource.build_candidates(query, collect_fluids(), player.locale, translation, include_hidden)
end

function FluidSource.register()
  remote.add_interface("quidquid.fluid-source", { search = search })
  remote.call("quidquid", "register_source", {
    version = 1,
    id = "fluids",
    type = "fluid",
    label = SOURCE_LABEL,
    prefixes = { "f", "fluid" },
    default_active = true,
    interface = "quidquid.fluid-source",
  })
end

return FluidSource
