-- lib/temporary_request_editor_logic.lua
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
function TemporaryRequestEditorLogic.valid_quantity(value)
  if value == nil then
    return false
  end
  if value ~= math.floor(value) then
    return false
  end
  return value >= 0
end

return TemporaryRequestEditorLogic
