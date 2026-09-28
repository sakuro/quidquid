local ActionRunner = {}

--- Runs an action whose per-candidate feasibility is a runtime fact, resolving it
--- and returning the message that reports the outcome.
---
--- is_available only gates on state uniform across every candidate of a type, so a
--- fact specific to one candidate is resolved here instead, and reported rather
--- than silently hiding the action (see individual actions' is_available for what
--- that means for them).
---
--- The message is what execute returns to Palette, which shows it with the
--- candidate's icon and label in front (see EXTENDING.md "Messages"). With neither
--- locale key there is no message at all -- reserved for edge cases judged
--- impossible to reach in practice, where fallback_locale_key is for ones that are
--- merely rare (e.g. the candidate having stopped resolving to anything between
--- search and execute).
---@param candidate table
---@param player_index uint
---@param resolve_fn function  (candidate, player) -> payload|nil, locale_key|nil
---@param apply_fn function  (payload, candidate, player) -> message|nil, run for a
---  non-nil payload
---@param fallback_locale_key string|nil  used when resolve_fn returns no locale key
---  of its own
---@return table|nil  { locale_key } when resolving fails, otherwise apply_fn's message
function ActionRunner.run(candidate, player_index, resolve_fn, apply_fn, fallback_locale_key)
  local player = game.get_player(player_index)
  if player == nil then
    return nil
  end
  local payload, locale_key = resolve_fn(candidate, player)
  if payload == nil then
    local message_key = locale_key or fallback_locale_key
    if message_key == nil then
      return nil
    end
    return { message_key }
  end
  return apply_fn(payload, candidate, player)
end

return ActionRunner
