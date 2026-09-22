local ActionRunner = require("lib.action_runner")

local CraftAction = {}

local function resolve_recipe(player, selected_candidate)
  -- Both candidate types use the candidate id as the recipe name. Recipe
  -- candidates are backed by prototypes.recipe for searching, but crafting
  -- requires the force's runtime recipe.
  return player.force.recipes[selected_candidate.id]
end

-- pure, testable: true when character's prototype can hand-craft at least one of
-- recipe's categories. A recipe whose categories are all machine-only (e.g.
-- smelting) can never be hand-crafted, regardless of the force-level
-- get_hand_crafting_disabled_for_recipe flag -- that flag toggles a recipe that
-- otherwise CAN be hand-crafted, it doesn't cover this case.
function CraftAction.hand_craftable(recipe, character)
  if character == nil then
    return false
  end
  local crafting_categories = character.prototype.crafting_categories or {}
  for _, category in ipairs(recipe.categories) do
    if crafting_categories[category] then
      return true
    end
  end
  return false
end

-- Decides whether selected_candidate can be hand-crafted right now. Returns the
-- recipe to craft, or nil plus a locale key explaining why not (nil, nil for a
-- recipe candidate with no matching force recipe -- a near-impossible case not worth
-- a message, since RecipeSource builds candidates from prototypes.recipe directly).
-- Each check here corresponds to a distinct way LuaControl.begin_crafting can fail
-- silently or with one of Factorio's own (iconless, un-attributed) native flying
-- texts -- see project_craft_action_resolve_craftable_gaps memory for how each was
-- found. is_available only gates by candidate type (via this action's registered
-- `types`); per-candidate craftability is a runtime fact about this specific
-- item/recipe, so it's resolved here and reported by execute, not hidden from the
-- tooltip.
function CraftAction.resolve_craftable(selected_candidate, player)
  local recipe = resolve_recipe(player, selected_candidate)
  if recipe == nil then
    if selected_candidate.type == "item" then
      return nil, "quidquid.action-craft-no-recipe"
    end
    return nil, nil
  end
  if not recipe.enabled then
    return nil, "quidquid.action-craft-not-researched"
  end
  -- Same locale key for both: Factorio's own recipe-not-craftable-in-hand message
  -- doesn't distinguish a force-disabled recipe from one whose category was never
  -- hand-craftable in the first place, so quidquid's message doesn't either.
  if
    player.force.get_hand_crafting_disabled_for_recipe(recipe)
    or not CraftAction.hand_craftable(recipe, player.character)
  then
    return nil, "quidquid.action-craft-hand-crafting-disabled"
  end
  if player.get_craftable_count(recipe) <= 0 then
    return nil, "quidquid.action-craft-not-enough-ingredients"
  end
  return recipe, nil
end

function CraftAction.fixed_count(n)
  return function(_player, _recipe)
    return n
  end
end

-- resolve_craftable already rejects a recipe with zero craftable count before this
-- is ever called, so the count here is always positive.
function CraftAction.max_craftable(player, recipe)
  return player.get_craftable_count(recipe)
end

local function craft(count_for)
  return function(selected_candidate, player_index)
    ActionRunner.run(
      selected_candidate,
      player_index,
      CraftAction.resolve_craftable,
      function(recipe, _candidate, player)
        player.begin_crafting({ count = count_for(player, recipe), recipe = recipe })
      end
    )
  end
end

local function register(id, input_name, interface, label, count_for)
  remote.add_interface(interface, { execute = craft(count_for) })
  remote.call("quidquid", "register_action", {
    contract_version = 1,
    id = id,
    types = { "item", "recipe" },
    label = label,
    input_name = input_name,
    interface = interface,
  })
end

function CraftAction.register()
  register(
    "craft-1",
    "quidquid-craft-1",
    "quidquid.craft-1-action",
    { "quidquid.action-craft-1" },
    CraftAction.fixed_count(1)
  )
  register(
    "craft-5",
    "quidquid-craft-5",
    "quidquid.craft-5-action",
    { "quidquid.action-craft-5" },
    CraftAction.fixed_count(5)
  )
  register(
    "craft-all",
    "quidquid-craft-all",
    "quidquid.craft-all-action",
    { "quidquid.action-craft-all" },
    CraftAction.max_craftable
  )
end

return CraftAction
