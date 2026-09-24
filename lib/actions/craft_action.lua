local ActionRunner = require("lib.action_runner")

local CraftAction = {}

-- The force's runtime recipe for a candidate. Both candidate types use the candidate
-- id as the recipe name: recipe candidates are backed by prototypes.recipe for
-- searching, but crafting needs the force's own recipe.
local function resolve_recipe(selected_candidate, player)
  return player.force.recipes[selected_candidate.id]
end

--- True when character's prototype can hand-craft at least one of recipe's
--- categories.
---
--- A recipe whose categories are all machine-only (e.g. smelting) can never be
--- hand-crafted, regardless of the force-level get_hand_crafting_disabled_for_recipe
--- flag -- that flag toggles a recipe that otherwise CAN be hand-crafted, it doesn't
--- cover this case.
---@param recipe LuaRecipe
---@param character LuaEntity|nil  false when there is no character at all
---@return boolean
function CraftAction.is_hand_craftable(recipe, character)
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

--- Decides whether selected_candidate can be hand-crafted right now.
---
--- Each check here corresponds to a distinct way LuaControl.begin_crafting can fail
--- silently, or with one of Factorio's own iconless, un-attributed native flying
--- texts.
---
--- is_available only gates by candidate type (via this action's registered `types`);
--- per-candidate craftability is a runtime fact about this specific item/recipe, so
--- it is resolved here and reported by execute rather than hidden from the tooltip.
---@param selected_candidate table
---@param player LuaPlayer
---@return LuaRecipe|nil  the recipe to craft
---@return string|nil  locale key explaining a nil recipe; nil for a recipe candidate
---  with no matching force recipe -- a near-impossible case not worth a message,
---  since RecipeSource builds candidates from prototypes.recipe directly
function CraftAction.resolve_craftable(selected_candidate, player)
  local recipe = resolve_recipe(selected_candidate, player)
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
    or not CraftAction.is_hand_craftable(recipe, player.character)
  then
    return nil, "quidquid.action-craft-hand-crafting-disabled"
  end
  if player.get_craftable_count(recipe) <= 0 then
    return nil, "quidquid.action-craft-not-enough-ingredients"
  end
  return recipe, nil
end

--- A count_for function that always crafts n, for the Craft 1 and Craft 5 actions.
---@param n number
---@return function  (player, recipe) -> number
function CraftAction.fixed_count(n)
  return function(_player, _recipe)
    return n
  end
end

--- A count_for function for the Craft all action: as many as the ingredients allow.
---
--- resolve_craftable already rejects a recipe with zero craftable count before this is
--- ever called, so the count here is always positive.
---@param player LuaPlayer
---@param recipe LuaRecipe
---@return number
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

--- Adds the three craft actions' remote interfaces and registers them with Quidquid.
---
--- Craft 1, Craft 5 and Craft all differ only in how many crafts they start, so they
--- share one execute path and one resolve step.
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
