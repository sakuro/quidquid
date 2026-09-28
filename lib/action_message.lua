local ActionMessage = {}

-- A LocalisedString takes at most 20 parameters; the icon and label use two.
ActionMessage.MAX_PARAMETERS = 18

--- The LocalisedString to show for a message an action's execute returned.
---
--- The candidate's icon and label go first, as __1__ and __2__, so every action names
--- its subject the same way; the message's own parameters follow from __3__. The
--- message comes from another mod's remote interface, so its shape is checked rather
--- than trusted.
---@param candidate table
---@param message any  execute's return value
---@return table|nil  the LocalisedString, or nil when the message is malformed
---@return string|nil  why the message was rejected
function ActionMessage.localise(candidate, message)
  if type(message) ~= "table" then
    return nil, ("expected a table, got %s"):format(type(message))
  end
  if type(message[1]) ~= "string" then
    return nil, "the first element is not a locale key string"
  end
  local parameter_count = #message - 1
  if parameter_count > ActionMessage.MAX_PARAMETERS then
    return nil, ("%d parameters, at most %d allowed"):format(parameter_count, ActionMessage.MAX_PARAMETERS)
  end
  local localised = { message[1], "[img=" .. candidate.icon .. "]", candidate.label }
  for i = 2, #message do
    table.insert(localised, message[i])
  end
  return localised, nil
end

return ActionMessage
