local PaletteLogic = {}

local function candidate_score(entry)
  if type(entry) ~= "table" then
    return nil
  end
  if type(entry.candidate) == "table" then
    return entry.candidate.search_score
  end
  return entry.search_score
end

function PaletteLogic.merge_candidates(results, limit)
  local scored = {}
  local has_scores = false
  local order = 0
  for _, candidates in ipairs(results) do
    for _, entry in ipairs(candidates) do
      order = order + 1
      local score = candidate_score(entry)
      if score ~= nil then
        has_scores = true
      end
      table.insert(scored, { entry = entry, score = score or -math.huge, order = order })
    end
  end

  if has_scores then
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
