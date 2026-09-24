local OpenFactoriopediaAction = {}

local ActionRunner = require("lib.action_runner")
local SurfaceAccess = require("lib.surface_access")

-- pure decision logic given an already-resolved surface: dispatches on the
-- LuaSurface's own kind rather than SurfaceAccess's descriptor, since resolve()'s
-- descriptor isn't available for a real generated surface (only carried for the
-- ungenerated-planet fallback SurfaceAccess.resolve already handles internally).
local function surface_prototype(surface)
  if surface.platform ~= nil then
    return prototypes.surface["space-platform"]
  elseif surface.planet ~= nil then
    return surface.planet.prototype
  end
  return nil
end

--- The prototype whose Factoriopedia page a candidate should open.
---
--- A surface candidate is the awkward one: a generated surface resolves through its
--- LuaSurface, while an ungenerated planet has only its prototype to offer.
---@param candidate table
---@param player LuaPlayer
---@return LuaPrototypeBase|nil  nil for a candidate type with no page, or one that no
---  longer resolves
function OpenFactoriopediaAction.resolve_prototype(candidate, player)
  if candidate.type == "item" then
    return prototypes.item[candidate.id]
  elseif candidate.type == "fluid" then
    return prototypes.fluid[candidate.id]
  elseif candidate.type == "recipe" then
    return prototypes.recipe[candidate.id]
  elseif candidate.type == "resource" then
    return prototypes.entity[candidate.resource_name]
  elseif candidate.type == "surface" then
    local surface = SurfaceAccess.resolve(candidate, player)
    if surface ~= nil then
      return surface_prototype(surface)
    end
    return SurfaceAccess.planet_prototype(candidate)
  end
  return nil
end

-- Adapts the single-value resolve_prototype to ActionRunner's (payload, locale_key)
-- convention: every failure shows the same generic message, unlike other actions'
-- resolve functions, since Factoriopedia has no distinct reasons to report.
local function resolve(candidate, player)
  local prototype = OpenFactoriopediaAction.resolve_prototype(candidate, player)
  if prototype == nil then
    return nil, "quidquid.action-open-factoriopedia-unavailable"
  end
  return prototype, nil
end

-- is_available only gates by candidate type (via this action's registered `types`);
-- whether the prototype actually resolves for this specific candidate is a
-- per-candidate runtime fact, so it's resolved here and reported by execute, not
-- hidden from the tooltip.
local function execute(selected_candidate, player_index)
  ActionRunner.run(selected_candidate, player_index, resolve, function(prototype, _candidate, player)
    player.open_factoriopedia_gui(prototype)
  end)
end

--- Adds this action's remote interface and registers it with Quidquid.
function OpenFactoriopediaAction.register()
  remote.add_interface("quidquid.open-factoriopedia-action", { execute = execute })
  remote.call("quidquid", "register_action", {
    contract_version = 1,
    id = "open-factoriopedia",
    types = { "item", "fluid", "recipe", "surface", "resource" },
    label = { "quidquid.action-open-factoriopedia" },
    input_name = "quidquid-open-factoriopedia",
    interface = "quidquid.open-factoriopedia-action",
  })
end

return OpenFactoriopediaAction
