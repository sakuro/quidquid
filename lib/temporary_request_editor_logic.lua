-- lib/temporary_request_editor_logic.lua
local TemporaryRequestEditorLogic = {}

-- pure, testable: rounds up to the next multiple of stack_size, strictly greater than
-- current_value even when current_value is already an exact multiple (pressing "+1
-- Stack" always adds at least one full stack, never a partial one).
function TemporaryRequestEditorLogic.next_stack_multiple(current_value, stack_size)
  return stack_size * (math.floor(current_value / stack_size) + 1)
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

return TemporaryRequestEditorLogic
