local TranslatedPrototypeSource = require("lib.sources.translated_prototype_source")
local build_candidates = require("lib.sources.prototype_candidate")

local TechnologySource = {}

local SOURCE_LABEL = { "quidquid.source-technologies" }

local function collect_technologies()
  local technologies = {}
  for _, technology in pairs(prototypes.technology) do
    table.insert(technologies, technology)
  end
  return technologies
end

local translation = TranslatedPrototypeSource.new("technologies", collect_technologies, SOURCE_LABEL)

function TechnologySource.build_candidates(query, technologies, locale, translation_cache, include_hidden)
  return build_candidates("technology", "technology", query, technologies, locale, translation_cache, include_hidden)
end

function TechnologySource.on_string_translated(event)
  translation:on_string_translated(event)
end

function TechnologySource.on_player_joined_game(event)
  translation:on_player_joined_game(event)
end

TechnologySource.on_player_locale_changed = TechnologySource.on_player_joined_game

function TechnologySource.on_player_left_game(event)
  translation:on_player_left_game(event)
end

function TechnologySource.on_init()
  translation:on_init()
end

function TechnologySource.on_configuration_changed()
  translation:on_configuration_changed()
end

local function search(query, player_index, _context)
  local player = game.get_player(player_index)
  if player == nil then
    return {}
  end
  local include_hidden = player.mod_settings["quidquid-include-hidden"].value
  return TechnologySource.build_candidates(query, collect_technologies(), player.locale, translation, include_hidden)
end

function TechnologySource.register()
  remote.add_interface("quidquid.technology-source", { search = search })
  remote.call("quidquid", "register_source", {
    version = 1,
    id = "technologies",
    type = "technology",
    label = SOURCE_LABEL,
    prefixes = { "t", "tech" },
    default_active = true,
    interface = "quidquid.technology-source",
  })
end

return TechnologySource
