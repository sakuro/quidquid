local ActionDispatch = require("lib.action_dispatch")

local CraftAction = {}

local function resolve_recipe(player, selected_candidate)
  -- Both candidate types use the candidate id as the recipe name. Recipe
  -- candidates are backed by prototypes.recipe for searching, but crafting
  -- requires the force's runtime recipe.
  return player.force.recipes[selected_candidate.id]
end

-- Decides whether selected_candidate can be hand-crafted right now. Returns the
-- recipe to craft, or nil plus a locale key explaining why not (nil, nil for a
-- recipe candidate with no matching force recipe -- a near-impossible case not worth
-- a message, since RecipeSource builds candidates from prototypes.recipe directly).
-- is_available only gates by candidate type (via this action's registered `types`);
-- per-candidate craftability is a runtime fact about this specific item/recipe, so
-- it's resolved here and reported by execute, not hidden from the tooltip.
function CraftAction.resolve_craftable(selected_candidate, player)
  local recipe = resolve_recipe(player, selected_candidate)
  if recipe == nil then
    if selected_candidate.type == "item" then
      return nil, "quidquid.action-craft-no-recipe"
    end
    return nil, nil
  end
  if player.force.get_hand_crafting_disabled_for_recipe(recipe) then
    return nil, "quidquid.action-craft-hand-crafting-disabled"
  end
  return recipe, nil
end

function CraftAction.count_of(n)
  return function(_player, _recipe)
    return n
  end
end

function CraftAction.max_craftable(player, recipe)
  return math.max(1, player.get_craftable_count(recipe))
end

local function craft(count_for)
  return function(selected_candidate, player_index)
    ActionDispatch.run(
      selected_candidate,
      player_index,
      CraftAction.resolve_craftable,
      function(recipe, _candidate, player)
        player.begin_crafting({ count = count_for(player, recipe), recipe = recipe })
      end
    )
  end
end

local function register(id, key, interface, label, count_for)
  remote.add_interface(interface, { execute = craft(count_for) })
  remote.call("quidquid", "register_action", {
    version = 1,
    id = id,
    types = { "item", "recipe" },
    label = label,
    key = key,
    interface = interface,
  })
end

function CraftAction.register()
  register(
    "craft-1",
    "quidquid-craft-1",
    "quidquid.craft-1-action",
    { "quidquid.action-craft-1" },
    CraftAction.count_of(1)
  )
  register(
    "craft-5",
    "quidquid-craft-5",
    "quidquid.craft-5-action",
    { "quidquid.action-craft-5" },
    CraftAction.count_of(5)
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
