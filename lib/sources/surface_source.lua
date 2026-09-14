local TranslatedPrototypeSource = require("lib.sources.translated_prototype_source")
local SurfaceAccess = require("lib.surface_access")
local SurfaceLogic = require("lib.surface_logic")

local SurfaceSource = {}
local SOURCE_LABEL = {"quidquid.source-surfaces"}

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

for _, method in ipairs({"on_init", "on_configuration_changed", "on_player_joined_game",
  "on_player_locale_changed", "on_player_left_game", "on_string_translated"}) do
  SurfaceSource[method] = function(event) translation[method](translation, event) end
end

local function search(query, player_index, _context)
  local player = game.get_player(player_index)
  if player == nil then return {} end
  local surfaces = {}
  for _, surface in pairs(game.surfaces) do
    local descriptor = SurfaceAccess.describe(surface, player)
    if descriptor ~= nil then
      if descriptor.planet_name ~= nil then
        local translated = translation:get(player.locale, descriptor.planet_name)
        if type(translated) == "string" then descriptor.search_name = translated end
      end
      table.insert(surfaces, descriptor)
    end
  end
  return SurfaceLogic.build_candidates(query, surfaces, player.mod_settings["quidquid-include-hidden"].value)
end

function SurfaceSource.register()
  remote.add_interface("quidquid.surface-source", {search = search})
  remote.call("quidquid", "register_source", {
    version = 1, id = "surfaces", type = "surface", label = SOURCE_LABEL,
    prefixes = {"s", "surface"}, default_active = true,
    interface = "quidquid.surface-source",
  })
end

return SurfaceSource
