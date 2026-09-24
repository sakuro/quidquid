local ItemCounts = {}

--- Combines any number of contents arrays into one name -> quality -> count index.
---
--- Each argument is already fetched by the caller from whatever real inventories or
--- logistic network are relevant (main inventory, cursor stack, ammo, guns).
--- Confirmed over RCON that `character.get_item_count` alone doesn't cover all of
--- those uniformly across quality, so callers fetch each source's get_contents() and
--- merge them here instead. Matching name/quality entries across arguments are
--- summed, not overwritten.
---@param ... table  `get_contents()`-shaped arrays of { name, quality, count }
---@return table  name -> quality -> count
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

--- Sums an item's count across every quality.
---
--- The row's headline number, which doesn't distinguish quality.
---@param index table  as returned by merge
---@param name string
---@return number  0 for an item the index doesn't hold
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

--- The per-quality breakdown for the tooltip, lowest tier first.
---
--- Callers decide whether it's worth showing (e.g. only when more than one quality
--- is present). The tier lookup is taken as plain data rather than read from
--- `prototypes` here, which is what keeps this module free of the runtime.
---
--- Confirmed over RCON that quality levels aren't contiguous (normal=0, uncommon=1,
--- rare=2, epic=3, legendary=5) and that a level can repeat (quality-unknown=0, same
--- as normal), so ties -- including an omitted quality_order entry, treated as tying
--- at level 0 -- fall back to quality name for a stable order.
---@param index table  as returned by merge
---@param name string
---@param quality_order table|nil  quality name -> tier level, e.g. from
---  prototypes.quality[name].level; nil sorts alphabetically instead
---@return table  array of { quality, count }, empty for an item the index doesn't hold
function ItemCounts.breakdown(index, name, quality_order)
  local by_quality = index[name]
  if by_quality == nil then
    return {}
  end
  local list = {}
  for quality, count in pairs(by_quality) do
    table.insert(list, { quality = quality, count = count })
  end
  table.sort(list, function(a, b)
    if quality_order ~= nil then
      local a_level = quality_order[a.quality] or 0
      local b_level = quality_order[b.quality] or 0
      if a_level ~= b_level then
        return a_level < b_level
      end
    end
    return a.quality < b.quality
  end)
  return list
end

return ItemCounts
