local SurfaceLogic = require("lib.surface_logic")

local SurfaceAccess = {}

function SurfaceAccess.describe(surface, player)
  local platform = surface.platform
  if platform ~= nil then
    local owner = platform.force
    return {
      index = surface.index,
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
    descriptor.index = surface.index
    descriptor.name = surface.name
    descriptor.generated = true
    descriptor.hidden = planet.prototype.hidden or player.force.get_surface_hidden(surface)
    return descriptor
  end
  return nil
end

function SurfaceAccess.describe_planet(planet, player)
  return {
    index = planet.name,
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

function SurfaceAccess.resolve(candidate, player)
  if candidate.type ~= "surface" then
    return nil
  end
  local surface = game.get_surface(candidate.id)
  if surface == nil then
    return nil
  end
  local descriptor = SurfaceAccess.describe(surface, player)
  if
    descriptor ~= nil and SurfaceLogic.is_visible(descriptor, player.mod_settings["quidquid-include-hidden"].value)
  then
    return surface, descriptor
  end
  return nil
end

function SurfaceAccess.resolve_remote_view(candidate, player)
  local surface, descriptor = SurfaceAccess.resolve(candidate, player)
  if
    surface ~= nil
    and SurfaceLogic.can_open_remote_view(descriptor, player.mod_settings["quidquid-include-hidden"].value)
  then
    return surface
  end
  return nil
end

return SurfaceAccess
