local OpenFactoriopediaAction = {}

local SurfaceAccess = require("lib.surface_access")

local function resolve_prototype(candidate, player)
  if candidate.type == "item" then
    return prototypes.item[candidate.id]
  elseif candidate.type == "fluid" then
    return prototypes.fluid[candidate.id]
  elseif candidate.type == "recipe" then
    return prototypes.recipe[candidate.id]
  elseif candidate.type == "surface" then
    local surface = SurfaceAccess.resolve(candidate, player)
    if surface ~= nil then
      if surface.platform ~= nil then
        return prototypes.surface["space-platform"]
      elseif surface.planet ~= nil then
        return surface.planet.prototype
      end
    else
      return SurfaceAccess.planet_prototype(candidate)
    end
  end
  return nil
end

local function is_applicable(candidate, player_index)
  local player = game.get_player(player_index)
  return player ~= nil and resolve_prototype(candidate, player) ~= nil
end

local function execute(selected_candidate, _params, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return
  end
  local prototype = resolve_prototype(selected_candidate, player)
  if prototype == nil then
    log(
      ("quidquid: open-factoriopedia could not resolve prototype '%s' of type '%s'"):format(
        tostring(selected_candidate.id),
        tostring(selected_candidate.type)
      )
    )
    return
  end
  player.open_factoriopedia_gui(prototype)
end

function OpenFactoriopediaAction.register()
  remote.add_interface("quidquid.open-factoriopedia-action", { execute = execute, is_applicable = is_applicable })
  remote.call("quidquid", "register_action", {
    version = 1,
    id = "open-factoriopedia",
    types = { "item", "fluid", "recipe", "surface" },
    label = { "quidquid.action-open-factoriopedia" },
    key = "quidquid-open-factoriopedia",
    interface = "quidquid.open-factoriopedia-action",
  })
end

return OpenFactoriopediaAction
