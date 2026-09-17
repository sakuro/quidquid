local flib_dictionary = require("__flib__.dictionary")
local build_candidates = require("lib.sources.prototype_candidate")

local TechnologySource = {}

local SOURCE_LABEL = { "quidquid.source-technologies" }
local NAMESPACE = "technologies"

local function collect_technologies()
  local technologies = {}
  for _, technology in pairs(prototypes.technology) do
    table.insert(technologies, technology)
  end
  return technologies
end

function TechnologySource.register_dictionary()
  flib_dictionary.new(NAMESPACE)
  for _, technology in ipairs(collect_technologies()) do
    flib_dictionary.add(NAMESPACE, technology.name, technology.localised_name)
  end
end

function TechnologySource.build_candidates(query, technologies, locale, translated_names, include_hidden)
  return build_candidates("technology", "technology", query, technologies, locale, translated_names, include_hidden)
end

local function search(query, player_index, _context)
  local player = game.get_player(player_index)
  if player == nil then
    return {}
  end
  local include_hidden = player.mod_settings["quidquid-include-hidden"].value
  local translated_names = flib_dictionary.get(player_index, NAMESPACE) or {}
  return TechnologySource.build_candidates(
    query,
    collect_technologies(),
    player.locale,
    translated_names,
    include_hidden
  )
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
