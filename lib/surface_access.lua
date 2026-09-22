local SurfaceLogic = require("lib.surface_logic")

local SurfaceAccess = {}

function SurfaceAccess.describe(surface, player)
  local platform = surface.platform
  if platform ~= nil then
    local owner = platform.force
    return {
      id = surface.name,
      name = surface.name,
      kind = "platform",
      label = platform.name,
      search_name = platform.name,
      icon = "surface/space-platform",
      force_name = owner.name,
      own = owner == player.force,
      friendly = owner.get_friend(player.force),
      hidden = platform.hidden or player.force.get_surface_hidden(surface),
    }
  end
  local planet = surface.planet
  if planet ~= nil then
    local descriptor = SurfaceAccess.describe_planet(planet, player)
    -- A planet's generated surface is always named after the planet
    -- (confirmed empirically via RCON), so this is a no-op in value -- but
    -- it comes from the actual LuaSurface in hand rather than relying on
    -- that invariant.
    descriptor.id = surface.name
    descriptor.name = surface.name
    descriptor.generated = true
    descriptor.hidden = planet.prototype.hidden or player.force.get_surface_hidden(surface)
    return descriptor
  end
  return nil
end

function SurfaceAccess.describe_planet(planet, player)
  return {
    id = planet.name,
    name = planet.name,
    kind = "planet",
    label = planet.prototype.localised_name,
    planet_name = planet.name,
    icon = "space-location/" .. planet.name,
    unlocked = player.force.is_space_location_unlocked(planet.name),
    hidden = planet.prototype.hidden,
    generated = false,
  }
end

function SurfaceAccess.planet_prototype(candidate)
  if candidate.type ~= "surface" or candidate.planet_name == nil then
    return nil
  end
  local planet = game.planets[candidate.planet_name]
  return planet ~= nil and planet.prototype or nil
end

-- Returns (surface, descriptor). `surface` is nil for a planet that has no
-- LuaSurface yet (never visited/generated) -- there's nothing to act on -- but
-- `descriptor` is still populated from the planet prototype in that case, so
-- callers that only need to reason about availability (not act on a real surface)
-- still get one.
function SurfaceAccess.resolve(candidate, player)
  if candidate.type ~= "surface" then
    return nil
  end
  local surface = game.get_surface(candidate.id)
  local descriptor
  if surface ~= nil then
    descriptor = SurfaceAccess.describe(surface, player)
  elseif candidate.planet_name ~= nil then
    local planet = game.planets[candidate.planet_name]
    if planet ~= nil then
      descriptor = SurfaceAccess.describe_planet(planet, player)
    end
  end
  if
    descriptor ~= nil and SurfaceLogic.is_visible(descriptor, player.mod_settings["quidquid-include-hidden"].value)
  then
    return surface, descriptor
  end
  return nil
end

-- Returns the surface, or nil plus a locale key explaining why not (nil, nil for a
-- candidate that doesn't resolve to a surface/planet at all).
function SurfaceAccess.resolve_remote_view(candidate, player)
  local surface, descriptor = SurfaceAccess.resolve(candidate, player)
  if descriptor == nil then
    return nil, nil
  end
  local ok, reason_locale_key =
    SurfaceLogic.remote_view_availability(descriptor, player.mod_settings["quidquid-include-hidden"].value)
  if ok then
    return surface, nil
  end
  return nil, reason_locale_key
end

return SurfaceAccess
