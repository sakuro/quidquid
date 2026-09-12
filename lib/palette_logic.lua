local PaletteLogic = {}

function PaletteLogic.merge_candidates(results, limit)
  local merged = {}
  local cursors = {}
  for i = 1, #results do
    cursors[i] = 1
  end

  local any_remaining = true
  while any_remaining and #merged < limit do
    any_remaining = false
    for i = 1, #results do
      if #merged >= limit then
        break
      end
      local candidates = results[i]
      local cursor = cursors[i]
      if cursor <= #candidates then
        table.insert(merged, candidates[cursor])
        cursors[i] = cursor + 1
        if cursor + 1 <= #candidates then
          any_remaining = true
        end
      end
    end
  end

  return merged
end

function PaletteLogic.resolve_confirm_key(shift, control)
  if control then
    return "confirm-ctrl"
  elseif shift then
    return "confirm-shift"
  else
    return "confirm"
  end
end

function PaletteLogic.badge_number(index)
  if index > 10 then
    return nil
  elseif index == 10 then
    return 0
  end
  return index
end

return PaletteLogic
