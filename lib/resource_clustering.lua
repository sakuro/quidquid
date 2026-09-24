local ResourceClustering = {}

--- The storage key for one chunk position.
---
--- A string rather than a nested table so a chunk can index a flat map, which is what
--- neighbour lookups walk on every insert.
---@param x number  chunk x, not tile x
---@param y number  chunk y, not tile y
---@return string
function ResourceClustering.chunk_key(x, y)
  return x .. "," .. y
end

--- The eight chunk keys surrounding one chunk.
---
--- Diagonals are included because a patch that clips a chunk corner still reads as one
--- patch to a player -- see README "Resources" on loose merging.
---@param key string  as chunk_key returns it
---@return string[]  eight keys, excluding the chunk itself; order is not guaranteed
function ResourceClustering.neighbour_keys(key)
  local x, y = key:match("^(-?%d+),(-?%d+)$")
  x, y = tonumber(x), tonumber(y)
  local keys = {}
  for dx = -1, 1 do
    for dy = -1, 1 do
      if dx ~= 0 or dy ~= 0 then
        table.insert(keys, ResourceClustering.chunk_key(x + dx, y + dy))
      end
    end
  end
  return keys
end

--- One chunk's resource entities, summed per resource name.
---
--- Reads only `.name`, `.amount` and `.position`, so a spec can hand it plain tables
--- where the runtime hands it a LuaEntity array -- no per-entity allocation on the
--- scanning path.
---@param entities table  array of things answering .name, .amount and .position
---@return table  resource name -> { amount, tiles, left, top, right, bottom }
function ResourceClustering.group_chunk(entities)
  local grouped = {}
  for _, entity in ipairs(entities) do
    local entry = grouped[entity.name]
    local position = entity.position
    if entry == nil then
      grouped[entity.name] = {
        amount = entity.amount,
        tiles = 1,
        left = position.x,
        top = position.y,
        right = position.x,
        bottom = position.y,
      }
    else
      entry.amount = entry.amount + entity.amount
      entry.tiles = entry.tiles + 1
      entry.left = math.min(entry.left, position.x)
      entry.top = math.min(entry.top, position.y)
      entry.right = math.max(entry.right, position.x)
      entry.bottom = math.max(entry.bottom, position.y)
    end
  end
  return grouped
end

return ResourceClustering
