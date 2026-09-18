local ActionDispatch = {}

-- Shared flow for an action whose per-candidate feasibility is a runtime fact
-- resolved here rather than gated by is_available (is_available only gates on
-- state uniform across every candidate of a type; see individual actions'
-- is_available for what that means for them).
--
-- resolve_fn(candidate, player) -> payload_or_nil, key_or_nil. A non-nil payload
-- runs apply_fn(payload, candidate, player). A nil payload shows key (or
-- fallback_key, when resolve_fn returned no key of its own) as flying text naming
-- the candidate -- an icon (__1__) followed by its label (__2__), matching how
-- the temporary-request editor's own confirm messages cite an item/recipe -- with
-- neither key nor fallback_key, nothing is shown -- reserved for edge cases judged
-- impossible to reach in practice, where fallback_key is for ones that are merely
-- rare (e.g. the candidate having stopped resolving to anything between search and
-- execute).
function ActionDispatch.run(candidate, player_index, resolve_fn, apply_fn, fallback_key)
  local player = game.get_player(player_index)
  if player == nil then
    return
  end
  local payload, key = resolve_fn(candidate, player)
  if payload == nil then
    local shown_key = key or fallback_key
    if shown_key ~= nil then
      player.create_local_flying_text({
        text = { shown_key, "[img=" .. candidate.icon .. "]", candidate.label },
        create_at_cursor = true,
      })
    end
    return
  end
  apply_fn(payload, candidate, player)
end

return ActionDispatch
