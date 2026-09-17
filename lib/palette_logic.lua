local PaletteLogic = {}

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
