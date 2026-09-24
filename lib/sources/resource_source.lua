local ResourceClustering = require("lib.resource_clustering")

local ResourceSource = {}

local SCHEMA_VERSION = 1
local SCAN_CHUNKS_PER_TICK = 8

-- Every handler starts from here and returns early on nil. ensure_storage runs from
-- on_init and on_configuration_changed, which together cover the mod being added, so
-- nil should be unreachable -- but an event firing against a half-initialised storage
-- would otherwise be a nil index deep inside the clustering code.
local function state()
  return storage.resources
end

local function store_for(surface_index)
  local resources = state()
  local store = resources.surfaces[surface_index]
  if store == nil then
    store = ResourceClustering.new_store()
    resources.surfaces[surface_index] = store
  end
  return store
end

local function enqueue(surface_index, x, y)
  table.insert(state().queue, { surface_index = surface_index, x = x, y = y })
end

local function enqueue_everything()
  for _, surface in pairs(game.surfaces) do
    for chunk in surface.get_chunks() do
      enqueue(surface.index, chunk.x, chunk.y)
    end
  end
end

local function scan(surface_index, x, y)
  local surface = game.get_surface(surface_index)
  if surface == nil then
    return
  end
  local entities = surface.find_entities_filtered({
    area = { left_top = { x * 32, y * 32 }, right_bottom = { (x + 1) * 32, (y + 1) * 32 } },
    type = "resource",
  })
  if #entities == 0 then
    return
  end
  local key = ResourceClustering.chunk_key(x, y)
  local store = store_for(surface_index)
  for resource_name, entry in pairs(ResourceClustering.group_chunk(entities)) do
    ResourceClustering.insert(store, surface_index, resource_name, key, entry)
  end
end

--- Creates the cluster cache, or throws it away when its shape has changed.
---
--- A schema bump is the whole migration: the cache is discarded and every charted
--- chunk re-enqueued for the background scan, so no per-version migration code is
--- needed. Run from on_init and on_configuration_changed.
function ResourceSource.ensure_storage()
  local resources = storage.resources
  if resources ~= nil and resources.version == SCHEMA_VERSION then
    return
  end
  storage.resources = { version = SCHEMA_VERSION, surfaces = {}, queue = {}, queue_head = 1 }
  enqueue_everything()
end

--- Scans a bounded slice of the pending chunk queue.
---
--- Bounded rather than exhaustive because the queue holds every charted chunk of every
--- surface when the mod is added to an existing save; scanning that in one tick would
--- freeze the load, with no progress to show and no way to resume. Registered from
--- control.lua's on_tick.
function ResourceSource.on_tick()
  local resources = state()
  if resources == nil then
    return
  end
  local scanned = 0
  while scanned < SCAN_CHUNKS_PER_TICK and resources.queue_head <= #resources.queue do
    local chunk = resources.queue[resources.queue_head]
    resources.queue_head = resources.queue_head + 1
    scan(chunk.surface_index, chunk.x, chunk.y)
    scanned = scanned + 1
  end
  if resources.queue_head > #resources.queue and #resources.queue > 0 then
    resources.queue = {}
    resources.queue_head = 1
  end
end

--- Queues a newly charted chunk for scanning.
---@param event table  on_chunk_charted
function ResourceSource.on_chunk_charted(event)
  if state() == nil then
    return
  end
  enqueue(event.surface_index, event.position.x, event.position.y)
end

--- Forgets the clusters' hold on deleted chunks.
---
--- A cluster losing a chunk is not a cluster splitting: it keeps the rest, and goes
--- away only once nothing is left. See issue #174.
---@param event table  on_chunk_deleted
function ResourceSource.on_chunk_deleted(event)
  local resources = state()
  local store = resources and resources.surfaces[event.surface_index] or nil
  if store == nil then
    return
  end
  for _, position in pairs(event.positions) do
    local key = ResourceClustering.chunk_key(position.x, position.y)
    for resource_name in pairs(store.owner) do
      ResourceClustering.remove_chunk(store, resource_name, key)
    end
  end
end

--- Drops a surface's clusters whole.
---
--- Surface indices are reused, so a leftover store would be read as another surface's
--- -- the same hazard lib/actions/open_remote_view_action.lua guards against for
--- remembered positions. Registered for both on_surface_deleted and on_surface_cleared.
---@param event table  on_surface_deleted or on_surface_cleared
function ResourceSource.on_surface_removed(event)
  local resources = state()
  if resources ~= nil then
    resources.surfaces[event.surface_index] = nil
  end
end

--- Subtracts an exhausted resource entity from its cluster.
---@param event table  on_resource_depleted
function ResourceSource.on_resource_depleted(event)
  local entity = event.entity
  if not entity.valid then
    return
  end
  local resources = state()
  local store = resources and resources.surfaces[entity.surface_index] or nil
  if store == nil then
    return
  end
  local key = ResourceClustering.chunk_key(math.floor(entity.position.x / 32), math.floor(entity.position.y / 32))
  ResourceClustering.subtract(store, entity.name, key, entity.amount)
end

--- Re-scans the chunk a scripted resource was placed in.
---
--- Mods place resources after a chunk has been charted and scanned; without this the
--- cache would never learn about them. Registered with a type filter so the handler is
--- not called for ordinary building.
---@param event table  on_built_entity, on_robot_built_entity or script_raised_built
function ResourceSource.on_built_entity(event)
  local entity = event.entity
  if state() == nil or entity == nil or not entity.valid or entity.type ~= "resource" then
    return
  end
  enqueue(entity.surface_index, math.floor(entity.position.x / 32), math.floor(entity.position.y / 32))
end

return ResourceSource
