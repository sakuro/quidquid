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
