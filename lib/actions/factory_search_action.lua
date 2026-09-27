local ActionRunner = require("lib.action_runner")
local RemoteCaller = require("lib.remote_caller")

local FactorySearchAction = {}

local INTERFACE = "factory-search"
-- The interop version this action was written against (FactorySearch 1.15.0). Another
-- value means FactorySearch may have changed its interface, so the action hides itself
-- rather than call it.
local INTEROP_VERSION = 1

local function product_signal(product)
  if type(product) == "table" and (product.type == "item" or product.type == "fluid") then
    return { type = product.type, name = product.name }
  end
  return nil
end

--- The SignalID FactorySearch should search for a candidate.
---
--- A recipe and a resource are mapped the way FactorySearch maps them for its own
--- "search the prototype under the cursor" input: a recipe to its main product, or to
--- its only product, and a resource to its first mineable product. No quality is set,
--- so FactorySearch's own "all qualities" toggle stays in effect.
---@param candidate table
---@return table|nil  a SignalID; nil when the candidate names no item or fluid
function FactorySearchAction.resolve_signal(candidate)
  if candidate.type == "item" or candidate.type == "fluid" then
    return { type = candidate.type, name = candidate.id }
  elseif candidate.type == "recipe" then
    local recipe = prototypes.recipe[candidate.id]
    if recipe == nil then
      return nil
    end
    local signal = product_signal(recipe.main_product)
    if signal == nil and #recipe.products == 1 then
      signal = product_signal(recipe.products[1])
    end
    return signal
  elseif candidate.type == "resource" then
    local entity = prototypes.entity[candidate.resource_name]
    local mineable = entity and entity.mineable_properties
    local products = mineable and mineable.products
    if products == nil then
      return nil
    end
    return product_signal(products[1])
  end
  return nil
end

--- True when FactorySearch's remote interface is loaded and speaks the interop version
--- this action was written against.
---@param caller table  RemoteCaller, or a stub with the same has/call methods
---@return boolean
function FactorySearchAction.interface_ready(caller)
  if not (caller:has(INTERFACE, "search") and caller:has(INTERFACE, "interop_version")) then
    return false
  end
  return caller:call(INTERFACE, "interop_version") == INTEROP_VERSION
end

local function resolve(candidate, _player)
  local signal = FactorySearchAction.resolve_signal(candidate)
  if signal == nil then
    return nil, "quidquid.action-factory-search-unavailable"
  end
  return signal, nil
end

-- Whether FactorySearch is present is the same for every candidate, so it gates here;
-- whether one candidate maps to an item or fluid is resolved and reported by execute.
local function is_available(_player_index)
  return FactorySearchAction.interface_ready(RemoteCaller)
end

local function execute(candidate, player_index)
  ActionRunner.run(candidate, player_index, resolve, function(signal, _candidate, player)
    -- FactorySearch's search takes the LuaPlayer itself, not its index.
    RemoteCaller:call(INTERFACE, "search", player, signal)
  end)
end

--- Adds this action's remote interface, named by its declaration in prototypes/actions.lua.
function FactorySearchAction.add_interface()
  remote.add_interface("quidquid.factory-search-action", { execute = execute, is_available = is_available })
end

return FactorySearchAction
