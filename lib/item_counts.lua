local ItemCounts = {}

-- pure, testable: each argument is a `get_contents()`-shaped array
-- ({name=, quality=, count=}), already fetched by the caller from whatever real
-- inventories or logistic network are relevant (e.g. main inventory, cursor stack,
-- ammo, guns -- confirmed over RCON that `character.get_item_count` alone doesn't
-- cover all of those uniformly across quality, so callers fetch each source's
-- get_contents() and merge them here instead). Matching name/quality entries across
-- arguments are summed, not overwritten, so passing several inventories' contents
-- combines them into one index.
function ItemCounts.merge(...)
  local index = {}
  for _, contents in ipairs({ ... }) do
    for _, entry in ipairs(contents) do
      local by_quality = index[entry.name]
      if by_quality == nil then
        by_quality = {}
        index[entry.name] = by_quality
      end
      by_quality[entry.quality] = (by_quality[entry.quality] or 0) + entry.count
    end
  end
  return index
end

-- Sums an item's count across every quality -- the row's headline number, which
-- doesn't distinguish quality.
function ItemCounts.total(index, name)
  local by_quality = index[name]
  if by_quality == nil then
    return 0
  end
  local total = 0
  for _, count in pairs(by_quality) do
    total = total + count
  end
  return total
end

-- The per-quality breakdown for the tooltip. Callers decide whether it's worth
-- showing (e.g. only when more than one quality is present).
function ItemCounts.breakdown(index, name)
  local by_quality = index[name]
  if by_quality == nil then
    return {}
  end
  local list = {}
  for quality, count in pairs(by_quality) do
    table.insert(list, { quality = quality, count = count })
  end
  table.sort(list, function(a, b)
    return a.quality < b.quality
  end)
  return list
end

return ItemCounts
