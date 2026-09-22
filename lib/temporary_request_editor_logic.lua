local TemporaryRequestEditorLogic = {}

-- pure, testable: rounds up to the next multiple of stack_size, strictly greater than
-- current_value even when current_value is already an exact multiple (pressing "+1
-- Stack" always adds at least one full stack, never a partial one).
function TemporaryRequestEditorLogic.next_stack_multiple(current_value, stack_size)
  return stack_size * (math.floor(current_value / stack_size) + 1)
end

-- pure, testable: rounds down to the previous multiple of stack_size, strictly less
-- than current_value even when current_value is already an exact multiple -- the mirror
-- of next_stack_multiple. Floored at 0 (a temporary request can't have a negative
-- quantity; 0 is meaningful on its own, as the "remove this request" case).
function TemporaryRequestEditorLogic.previous_stack_multiple(current_value, stack_size)
  return math.max(0, stack_size * (math.ceil(current_value / stack_size) - 1))
end

-- Recipe requests are measured in crafting operations, so their buttons change the
-- operation count directly rather than rounding to an item's stack size.
function TemporaryRequestEditorLogic.next_quantity(current_value)
  return current_value + 1
end

function TemporaryRequestEditorLogic.previous_quantity(current_value)
  return math.max(0, current_value - 1)
end

-- Converts recipe ingredients into the item requests needed for a number of crafts.
-- Fluids cannot be put into a personal logistics request and are intentionally omitted.
function TemporaryRequestEditorLogic.recipe_ingredients(ingredients, craft_count, quality)
  local recipe_ingredients = {}
  for _, ingredient in ipairs(ingredients or {}) do
    if ingredient.type == "item" then
      table.insert(recipe_ingredients, {
        name = ingredient.name,
        amount = ingredient.amount * craft_count,
        quality = quality,
      })
    end
  end
  return recipe_ingredients
end

-- Derives a recipe's operation count from existing per-ingredient request quantities.
-- The smallest complete count is used so every ingredient is available for that many
-- operations. A nil result means none of the recipe's ingredient requests exist yet.
function TemporaryRequestEditorLogic.recipe_craft_count(existing_quantities, ingredients)
  local craft_count = nil
  for _, ingredient in ipairs(ingredients or {}) do
    if ingredient.type == "item" then
      local quantity = existing_quantities[ingredient.name]
      if quantity ~= nil then
        local count = math.floor(quantity / ingredient.amount)
        craft_count = craft_count == nil and count or math.min(craft_count, count)
      else
        return nil
      end
    end
  end
  return craft_count
end

function TemporaryRequestEditorLogic.all_ingredients_satisfied(ingredients, get_item_count)
  for _, ingredient in ipairs(ingredients) do
    if get_item_count(ingredient.name, ingredient.quality) < ingredient.amount then
      return false
    end
  end
  return true
end

-- pure, testable: decides what Confirm should do, given the entered quantity and how
-- many the player currently holds of the selected item+quality. Doesn't know about GUI
-- or LuaLogisticSection at all -- the caller maps each outcome to the actual
-- set_slot/clear_slot call and flying-text message.
function TemporaryRequestEditorLogic.decide_confirm_action(quantity, already_have)
  if quantity == 0 then
    return "remove_zero"
  end
  if already_have >= quantity then
    return "remove_satisfied"
  end
  return "set"
end

-- pure, testable: decides whether a parsed quantity value (the result of evaluating
-- whatever the player typed, or nil if that failed to parse at all) is acceptable as a
-- temporary-request quantity -- a non-negative whole number. Doesn't know about GUI,
-- helpers.evaluate_expression, or textfield styles at all -- the caller maps this to the
-- error-background/Confirm-enabled state.
function TemporaryRequestEditorLogic.is_valid_quantity(value)
  if value == nil then
    return false
  end
  if value ~= math.floor(value) then
    return false
  end
  return value >= 0
end

return TemporaryRequestEditorLogic
