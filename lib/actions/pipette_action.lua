local ActionRunner = require("lib.action_runner")

local PipetteAction = {}

--- The one item a recipe candidate's pipette should target.
---
--- Either the recipe's sole product, when that is an item rather than a fluid, or its
--- main_product when it has several but names an unambiguous item one.
---
--- main_product is nil both when a recipe has multiple products with no declared main
--- one (e.g. uranium-processing, which splits into uranium-235/uranium-238 by
--- probability) and when a single-product recipe explicitly opts out of the
--- auto-inferred main product via main_product = "" (e.g. kovarex-enrichment-process,
--- for tooltip/icon reasons unrelated to pipetting). Both fall through to nil here,
--- same as any other genuinely ambiguous recipe.
---@param recipe LuaRecipePrototype
---@return LuaItemPrototype|nil  nil when the recipe names no unambiguous item product
function PipetteAction.resolve_item_prototype(recipe)
  local products = recipe.products
  if #products == 1 and products[1].type == "item" then
    return prototypes.item[products[1].name]
  end
  local main_product = recipe.main_product
  if main_product ~= nil and main_product.type == "item" then
    return prototypes.item[main_product.name]
  end
  return nil
end

local function resolve(candidate, _player)
  local prototype
  if candidate.type == "item" then
    prototype = prototypes.item[candidate.id]
  else
    local recipe = prototypes.recipe[candidate.id]
    prototype = recipe and PipetteAction.resolve_item_prototype(recipe)
  end
  if prototype == nil then
    return nil, "quidquid.action-pipette-no-item"
  end
  return prototype, nil
end

-- allow_ghost = true so this always offers a ghost when the player has none of the
-- item, regardless of the "pick ghost item if no items are available" interface
-- setting -- that setting isn't exposed to mods, so this is the only way to
-- guarantee the behavior rather than depend on the player's own client config.
local function execute(selected_candidate, player_index)
  ActionRunner.run(selected_candidate, player_index, resolve, function(prototype, _candidate, player)
    player.pipette(prototype, nil, true)
  end)
end

--- Adds this action's remote interface and registers it with Quidquid.
function PipetteAction.register()
  remote.add_interface("quidquid.pipette-action", { execute = execute })
  remote.call("quidquid", "register_action", {
    contract_version = 1,
    id = "pipette",
    types = { "item", "recipe" },
    label = { "controls.pipette" },
    input_name = "quidquid-pipette",
    interface = "quidquid.pipette-action",
  })
end

return PipetteAction
