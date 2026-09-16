local TranslatedPrototypeSource = require("lib.sources.translated_prototype_source")
local SurfaceAccess = require("lib.surface_access")
local SurfaceLogic = require("lib.surface_logic")

local SurfaceSource = {}
local SOURCE_LABEL = { "quidquid.source-surfaces" }

-- Translate prototype names, not the dynamic list of generated surfaces. Newly
-- generated planets can then be searched immediately using the existing cache.
local function collect_planets()
  local planets = {}
  for _, planet in pairs(game.planets) do
    table.insert(planets, planet.prototype)
  end
  return planets
end

local translation = TranslatedPrototypeSource.new("surfaces", collect_planets, SOURCE_LABEL)

function SurfaceSource.on_string_translated(event)
  translation:on_string_translated(event)
end

function SurfaceSource.on_player_joined_game(event)
  translation:on_player_joined_game(event)
end

SurfaceSource.on_player_locale_changed = SurfaceSource.on_player_joined_game

function SurfaceSource.on_player_left_game(event)
  translation:on_player_left_game(event)
end

function SurfaceSource.on_init()
  translation:on_init()
end

function SurfaceSource.on_configuration_changed()
  translation:on_configuration_changed()
end

local function search(query, player_index, _context)
  local player = game.get_player(player_index)
  if player == nil then
    return {}
  end
  local surfaces = {}
  local planet_indexes = {}

  for _, planet in pairs(game.planets) do
    local descriptor = SurfaceAccess.describe_planet(planet, player)
    local translated = translation:get(player.locale, planet.name)
    if type(translated) == "string" then
      descriptor.search_name = translated
    end
    table.insert(surfaces, descriptor)
    planet_indexes[planet.name] = #surfaces
  end

  for _, surface in pairs(game.surfaces) do
    local descriptor = SurfaceAccess.describe(surface, player)
    if descriptor ~= nil then
      if descriptor.planet_name ~= nil then
        local index = planet_indexes[descriptor.planet_name]
        if index ~= nil then
          local translated = translation:get(player.locale, descriptor.planet_name)
          if type(translated) == "string" then
            descriptor.search_name = translated
          end
          surfaces[index] = descriptor
        else
          table.insert(surfaces, descriptor)
        end
      else
        table.insert(surfaces, descriptor)
      end
    end
  end
  return SurfaceLogic.build_candidates(query, surfaces, player.mod_settings["quidquid-include-hidden"].value)
end

function SurfaceSource.register()
  remote.add_interface("quidquid.surface-source", { search = search })
  remote.call("quidquid", "register_source", {
    version = 1,
    id = "surfaces",
    type = "surface",
    label = SOURCE_LABEL,
    prefixes = { "s", "surface" },
    default_active = true,
    interface = "quidquid.surface-source",
  })
end

return SurfaceSource
