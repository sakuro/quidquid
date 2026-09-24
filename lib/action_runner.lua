local ActionRunner = {}

--- Runs an action whose per-candidate feasibility is a runtime fact, resolving it
--- and reporting the outcome to the player.
---
--- is_available only gates on state uniform across every candidate of a type, so a
--- fact specific to one candidate is resolved here instead, and reported rather
--- than silently hiding the action (see individual actions' is_available for what
--- that means for them).
---
--- The message for a nil payload is flying text naming the candidate: an icon
--- (__1__) followed by its label (__2__), matching how the temporary-request
--- editor's own confirm messages cite an item/recipe. With neither locale key,
--- nothing is shown at all -- reserved for edge cases judged impossible to reach
--- in practice, where fallback_locale_key is for ones that are merely rare (e.g.
--- the candidate having stopped resolving to anything between search and execute).
---@param candidate table
---@param player_index uint
---@param resolve_fn function  (candidate, player) -> payload|nil, locale_key|nil
---@param apply_fn function  (payload, candidate, player), run for a non-nil payload
---@param fallback_locale_key string|nil  shown when resolve_fn returns no locale key of its own
function ActionRunner.run(candidate, player_index, resolve_fn, apply_fn, fallback_locale_key)
  local player = game.get_player(player_index)
  if player == nil then
    return
  end
  local payload, locale_key = resolve_fn(candidate, player)
  if payload == nil then
    local shown_locale_key = locale_key or fallback_locale_key
    if shown_locale_key ~= nil then
      player.create_local_flying_text({
        text = { shown_locale_key, "[img=" .. candidate.icon .. "]", candidate.label },
        create_at_cursor = true,
      })
    end
    return
  end
  apply_fn(payload, candidate, player)
end

return ActionRunner
