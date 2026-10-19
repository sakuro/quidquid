local TemporaryRequestEditorLogic = {}

--- Rounds up to the next multiple of stack_size.
---
--- Strictly greater than current_value even when current_value is already an exact
--- multiple: pressing "+1 Stack" always adds at least one full stack, never a
--- partial one.
---@param current_value number
---@param stack_size number
---@return number
function TemporaryRequestEditorLogic.next_stack_multiple(current_value, stack_size)
  return stack_size * (math.floor(current_value / stack_size) + 1)
end

--- Rounds down to the previous multiple of stack_size.
---
--- Strictly less than current_value even when current_value is already an exact
--- multiple, mirroring next_stack_multiple. Floored at 0: a temporary request
--- can't have a negative quantity, and 0 is meaningful on its own as the "remove
--- this request" case.
---@param current_value number
---@param stack_size number
---@return number
function TemporaryRequestEditorLogic.previous_stack_multiple(current_value, stack_size)
  return math.max(0, stack_size * (math.ceil(current_value / stack_size) - 1))
end

--- Adds one to a recipe request's crafting-operation count.
---
--- Recipe requests are measured in crafting operations, so their buttons change the
--- operation count directly rather than rounding to an item's stack size.
---@param current_value number
---@return number
function TemporaryRequestEditorLogic.next_quantity(current_value)
  return current_value + 1
end

--- Takes one off a recipe request's crafting-operation count, floored at 0.
---@param current_value number
---@return number
function TemporaryRequestEditorLogic.previous_quantity(current_value)
  return math.max(0, current_value - 1)
end

--- Converts recipe ingredients into the item requests needed for a number of crafts.
---
--- Fluids cannot be put into a personal logistics request and are intentionally
--- omitted, so the result can be shorter than `ingredients`.
---@param ingredients table|nil  shaped like LuaRecipePrototype.ingredients
---@param craft_count number
---@param quality string  applied to every resulting request
---@return table  array of { name, amount, quality }
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

--- Derives a recipe's operation count from existing per-ingredient request
--- quantities.
---
--- The smallest complete count is used, so every ingredient is available for that
--- many operations.
---@param existing_quantities table  item name -> requested quantity
---@param ingredients table|nil  shaped like LuaRecipePrototype.ingredients
---@return number|nil  nil when any of the recipe's ingredient requests is missing
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

--- Decides what Confirm should do for the entered quantity, and which slots to write.
---
--- The entered quantity is an addition to whatever is already requested: Factorio adds
--- every section's request together, so the slot asks for exactly that quantity and
--- the target becomes the existing requests plus it. The temporary request therefore
--- disappears once the player holds that sum, and an ingredient already held at that
--- level needs no slot.
---
--- The counts come in as functions rather than tables so this stays independent of
--- where the caller reads inventories and logistic points from. Knows nothing about
--- GUI or LuaLogisticSection; the caller maps each outcome to the actual
--- set_slot/clear_slot call and flying-text message.
---@param quantity number
---@param ingredients table  array of { name, amount, quality }
---@param get_item_count function  (name, quality) -> number held
---@param get_other_requests function  (name, quality) -> number requested outside the
---  temporary section
---@return string  "remove_zero", "remove_satisfied" or "set"
---@return table  array of { name, quality, min, others } to write, `others` being what is
---  already requested elsewhere; non-empty only for "set"
function TemporaryRequestEditorLogic.plan_confirm(quantity, ingredients, get_item_count, get_other_requests)
  if quantity == 0 then
    return "remove_zero", {}
  end
  local requests = {}
  for _, ingredient in ipairs(ingredients) do
    local others = get_other_requests(ingredient.name, ingredient.quality)
    if get_item_count(ingredient.name, ingredient.quality) < others + ingredient.amount then
      table.insert(requests, {
        name = ingredient.name,
        quality = ingredient.quality,
        min = ingredient.amount,
        others = others,
      })
    end
  end
  if #requests > 0 then
    return "set", requests
  end
  return "remove_satisfied", {}
end

--- True when a parsed quantity is acceptable as a temporary-request quantity: a
--- non-negative whole number.
---
--- Knows nothing about GUI, helpers.evaluate_expression, or textfield styles; the
--- caller maps this to the error-background/Confirm-enabled state.
---@param value number|nil  the evaluation result, or nil when the input did not parse
---@return boolean
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
