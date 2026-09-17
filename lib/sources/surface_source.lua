local flib_dictionary = require("__flib__.dictionary")
local SurfaceAccess = require("lib.surface_access")
local SurfaceLogic = require("lib.surface_logic")

local SurfaceSource = {}
local SOURCE_LABEL = { "quidquid.source-surfaces" }
local NAMESPACE = "surfaces"

-- Translate prototype names, not the dynamic list of generated surfaces. Newly
-- generated planets can then be searched immediately using the existing cache.
local function collect_planets()
  local planets = {}
  for _, planet in pairs(game.planets) do
    table.insert(planets, planet.prototype)
  end
  return planets
end

function SurfaceSource.register_dictionary()
  flib_dictionary.new(NAMESPACE)
  for _, planet in ipairs(collect_planets()) do
    flib_dictionary.add(NAMESPACE, planet.name, planet.localised_name)
  end
end

local function search(query, player_index, _context)
  local player = game.get_player(player_index)
  if player == nil then
    return {}
  end
  local translated_names = flib_dictionary.get(player_index, NAMESPACE) or {}
  local surfaces = {}
  local planet_indexes = {}

  for _, planet in pairs(game.planets) do
    local descriptor = SurfaceAccess.describe_planet(planet, player)
    local translated = translated_names[planet.name]
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
          local translated = translated_names[descriptor.planet_name]
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
  return SurfaceLogic.build_candidates(
    query,
    surfaces,
    player.mod_settings["quidquid-include-hidden"].value,
    player.locale
  )
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
