local OpenFactoriopediaAction = {}

local ActionRunner = require("lib.action_runner")

--- The prototype whose Factoriopedia page a candidate should open.
---@param candidate table
---@param _player LuaPlayer  unused now that every remaining candidate type resolves from
---  prototypes alone; kept to match ActionRunner's resolve_fn(candidate, player) shape.
---@return LuaPrototypeBase|nil  nil for a candidate type with no page, or one that no
---  longer resolves
function OpenFactoriopediaAction.resolve_prototype(candidate, _player)
  if candidate.type == "item" then
    return prototypes.item[candidate.id]
  elseif candidate.type == "fluid" then
    return prototypes.fluid[candidate.id]
  elseif candidate.type == "recipe" then
    return prototypes.recipe[candidate.id]
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

local function execute(selected_candidate, player_index)
  return ActionRunner.run(selected_candidate, player_index, resolve, function(prototype, _candidate, player)
    player.open_factoriopedia_gui(prototype)
  end)
end

--- Adds this action's remote interface, named by its declaration in prototypes/actions.lua.
function OpenFactoriopediaAction.add_interface()
  remote.add_interface("quidquid.open-factoriopedia-action", { execute = execute })
end

return OpenFactoriopediaAction
