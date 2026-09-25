local PaletteLogic = {}

--- Merges every source's candidates into one ranked list, capped at limit.
---
--- Ties are broken by the order the candidates arrived, which is source
--- registration order -- so a tie is resolved deterministically rather than by
--- pairs(). A candidate without a numeric search_score raises here rather than
--- sorting unpredictably: EXTENDING.md states that this aborts the whole search, not
--- just that candidate.
---@param results table  one array of { candidate = ... } entries per searched source
---@param limit number
---@return table  the top entries, highest search_score first
function PaletteLogic.merge_candidates(results, limit)
  local scored = {}
  local order = 0
  for _, candidates in ipairs(results) do
    for _, entry in ipairs(candidates) do
      order = order + 1
      assert(
        type(entry) == "table" and type(entry.candidate) == "table" and type(entry.candidate.search_score) == "number",
        "all candidates must provide a numeric search_score"
      )
      table.insert(scored, { entry = entry, score = entry.candidate.search_score, order = order })
    end
  end

  table.sort(scored, function(a, b)
    if a.score ~= b.score then
      return a.score > b.score
    end
    return a.order < b.order
  end)
  local merged = {}
  for index = 1, math.min(limit, #scored) do
    table.insert(merged, scored[index].entry)
  end
  return merged
end

--- Merges a source's decoration onto the candidate it was computed for.
---
--- `decorate` runs after `search` and after the merge/trim, on only the rows about to be
--- shown, so any field it sets here wins over whatever `search` already put on that
--- candidate. `type`, `id` and `search_score` are excluded even when the decoration table
--- sets them: the first two are what actions resolve on and the third has already ordered
--- the rows the player is looking at, so letting a source rewrite any of them after the
--- fact would break dispatch or contradict the ranking on screen. They are silently
--- dropped rather than raising, matching how a broken `decorate` is merely logged and
--- ignored by its caller.
---@param candidate table  mutated in place
---@param decoration table|nil  fields to merge in; nil leaves the candidate untouched
function PaletteLogic.apply_decoration(candidate, decoration)
  if decoration == nil then
    return
  end
  for key, value in pairs(decoration) do
    if key ~= "type" and key ~= "id" and key ~= "search_score" then
      candidate[key] = value
    end
  end
end

--- The next selected row when the player moves the selection, wrapping at both ends.
---
--- With nothing selected yet, a downward move starts at the first row and an upward
--- one at the last, so the first keypress lands on a row either way.
---@param current_index number|nil
---@param count number  rows available
---@param direction number  +1 down, -1 up
---@return number|nil  nil when there is nothing to select
function PaletteLogic.move_index(current_index, count, direction)
  if count == 0 then
    return nil
  end

  local index = current_index or (direction > 0 and 0 or count + 1)
  index = index + direction
  if index < 1 then
    return count
  elseif index > count then
    return 1
  end
  return index
end

return PaletteLogic
