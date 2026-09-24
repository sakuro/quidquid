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

-- Recomputed from the cluster's chunks after every mutation rather than adjusted in
-- place. A cluster holds a handful of chunks, so this is cheap, and it removes the
-- class of bug where an incremental update drifts from the chunks it summarises.
local function recalculate(cluster)
  local amount, bounds = 0, nil
  for _, entry in pairs(cluster.chunks) do
    amount = amount + entry.amount
    if bounds == nil then
      bounds = { left = entry.left, top = entry.top, right = entry.right, bottom = entry.bottom }
    else
      bounds.left = math.min(bounds.left, entry.left)
      bounds.top = math.min(bounds.top, entry.top)
      bounds.right = math.max(bounds.right, entry.right)
      bounds.bottom = math.max(bounds.bottom, entry.bottom)
    end
  end
  cluster.amount = amount
  cluster.bounds = bounds
  return cluster
end

local function absorb(store, target, other)
  for key, entry in pairs(other.chunks) do
    target.chunks[key] = entry
    store.owner[other.resource_name][key] = target.id
  end
  store.clusters[other.id] = nil
end

--- An empty cluster store for one surface.
---@return table  { clusters = {}, owner = {} }; see this task's Interfaces
function ResourceClustering.new_store()
  return { clusters = {}, owner = {} }
end

--- Folds one chunk's worth of a resource into the store, merging with any neighbour.
---
--- Merging is by chunk adjacency alone, with no test of whether the resource actually
--- touches across the seam -- see issue #174 "On clusters that never split" for why
--- coarse boundaries are acceptable here. A chunk that bridges two clusters joins all
--- of them into one.
---@param store table  from new_store
---@param surface_index uint
---@param resource_name string
---@param key string  as chunk_key returns it
---@param entry table  as group_chunk produces per resource
---@return table  the cluster the chunk now belongs to
function ResourceClustering.insert(store, surface_index, resource_name, key, entry)
  local owner = store.owner[resource_name]
  if owner == nil then
    owner = {}
    store.owner[resource_name] = owner
  end

  local target = owner[key] and store.clusters[owner[key]] or nil
  for _, neighbour_key in ipairs(ResourceClustering.neighbour_keys(key)) do
    local neighbour = owner[neighbour_key] and store.clusters[owner[neighbour_key]] or nil
    if neighbour ~= nil then
      if target == nil then
        target = neighbour
      elseif neighbour.id ~= target.id then
        absorb(store, target, neighbour)
      end
    end
  end

  if target == nil then
    target = {
      id = resource_name .. ":" .. key,
      surface_index = surface_index,
      resource_name = resource_name,
      chunks = {},
    }
    store.clusters[target.id] = target
  end

  target.chunks[key] = entry
  owner[key] = target.id
  return recalculate(target)
end

--- Every cluster in the store, as an array.
---@param store table  from new_store
---@return table  array of clusters; order is not guaranteed
function ResourceClustering.all(store)
  local clusters = {}
  for _, cluster in pairs(store.clusters) do
    table.insert(clusters, cluster)
  end
  return clusters
end

return ResourceClustering
