local SurfaceLogic = require("lib.surface_logic")

local SurfaceAccess = {}

--- A plain-value descriptor for a real surface, as seen by one player's force.
---
--- Everything the surface source and the visibility rules need, flattened to plain
--- values so those decisions stay out of the runtime (see lib/surface_logic.lua).
--- Ownership and hidden-ness are per force, which is why the player comes in.
---@param surface LuaSurface
---@param player LuaPlayer
---@return table|nil  nil for a surface that is neither a platform nor a planet's
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

--- A descriptor for a planet, whether or not its surface exists yet.
---
--- `generated = false` here: a caller holding a real LuaSurface overwrites it. This is
--- what lets an unvisited planet still be searched and explain itself.
---@param planet LuaPlanet
---@param player LuaPlayer
---@return table
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

--- The planet prototype behind a surface candidate, for when no LuaSurface exists.
---@param candidate table
---@return LuaSpaceLocationPrototype|nil  nil unless the candidate names a real planet
function SurfaceAccess.planet_prototype(candidate)
  if candidate.type ~= "surface" or candidate.planet_name == nil then
    return nil
  end
  local planet = game.planets[candidate.planet_name]
  return planet ~= nil and planet.prototype or nil
end

--- Resolves a surface candidate to whatever of it exists, if the player may see it.
---
--- Both results are nil for a candidate the player cannot see at all, so a caller that
--- only checks visibility needs nothing else.
---@param candidate table
---@param player LuaPlayer
---@return LuaSurface|nil  nil for a planet with no surface yet (never visited), where
---  there is nothing to act on
---@return table|nil  the descriptor, still populated from the planet prototype in that
---  case, for callers reasoning about availability rather than acting
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

--- The surface remote view should open for a candidate, or why it can't.
---
--- Shaped for ActionRunner.run's (payload, locale_key) convention, which is what
--- OpenRemoteViewAction passes it as its resolve step.
---@param candidate table
---@param player LuaPlayer
---@return LuaSurface|nil
---@return string|nil  locale key explaining a nil surface; nil for a candidate that
---  does not resolve to a surface or planet at all, which is not worth a message
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
