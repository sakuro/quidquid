local PipetteAction = {}

-- Resolves the one item a recipe candidate's pipette should target: either its sole
-- product (when that's an item, not a fluid) or its main_product when the recipe has
-- several but names an unambiguous item one. main_product is nil both when a recipe
-- has multiple products with no declared main one (e.g. uranium-processing, which
-- splits into uranium-235/uranium-238 by probability) and when a single-product
-- recipe explicitly opts out of the auto-inferred main product via main_product = ""
-- (e.g. kovarex-enrichment-process, for tooltip/icon reasons unrelated to pipetting)
-- -- both cases fall through to nil here, same as any other genuinely ambiguous recipe.
local function resolve_item_prototype(recipe)
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

-- allow_ghost = true so this always offers a ghost when the player has none of the
-- item, regardless of the "pick ghost item if no items are available" interface
-- setting -- that setting isn't exposed to mods, so this is the only way to
-- guarantee the behavior rather than depend on the player's own client config.
local function execute(selected_candidate, _params, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return
  end

  local prototype
  if selected_candidate.type == "item" then
    prototype = prototypes.item[selected_candidate.id]
  else
    local recipe = prototypes.recipe[selected_candidate.id]
    prototype = recipe and resolve_item_prototype(recipe)
  end

  if prototype == nil then
    player.create_local_flying_text({
      text = { "quidquid.action-pipette-no-item" },
      create_at_cursor = true,
    })
    return
  end

  player.pipette(prototype, nil, true)
end

function PipetteAction.register()
  remote.add_interface("quidquid.pipette-action", { execute = execute })
  remote.call("quidquid", "register_action", {
    version = 1,
    id = "pipette",
    types = { "item", "recipe" },
    label = { "controls.pipette" },
    key = "quidquid-pipette",
    interface = "quidquid.pipette-action",
  })
end

return PipetteAction
