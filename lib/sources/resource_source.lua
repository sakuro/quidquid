local flib_dictionary = require("__flib__.dictionary")
local ResourceClustering = require("lib.resource_clustering")
local ResourceLogic = require("lib.resource_logic")

local ResourceSource = {}

local SCHEMA_VERSION = 2
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

  -- find_entities_filtered's area is a closed box, so an entity sitting exactly on a
  -- shared edge can come back for this chunk and its neighbour both. Keep only the
  -- entities this chunk actually owns, using the same floor-division on_resource_depleted
  -- and on_built_entity derive a chunk key from, so all three agree by construction.
  local owned = {}
  for _, entity in ipairs(entities) do
    local position = entity.position
    if math.floor(position.x / 32) == x and math.floor(position.y / 32) == y then
      table.insert(owned, entity)
    end
  end

  local grouped = ResourceClustering.group_chunk(owned)
  local existing_store = state().surfaces[surface_index]
  if next(grouped) == nil and existing_store == nil then
    return
  end

  local key = ResourceClustering.chunk_key(x, y)
  local store = store_for(surface_index)
  -- A resource this chunk held before but the rescan no longer finds (depleted to
  -- nothing, or removed) must be dropped, not just left stale -- see on_resource_depleted.
  for resource_name in pairs(store.owner) do
    if grouped[resource_name] == nil then
      ResourceClustering.remove_chunk(store, resource_name, key)
    end
  end
  for resource_name, entry in pairs(grouped) do
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

--- Re-scans the chunk an exhausted resource entity sat in.
---
--- `entity.amount` at this point is what's left, not what disappeared -- zero for a
--- finite resource, the minimum yield for an infinite one -- so subtracting it would
--- leave the cached amount permanently wrong instead of correcting it. Re-enqueuing
--- lets the background scan recompute the chunk's entry from what is actually still
--- there, the same way on_built_entity handles a chunk gaining a resource.
---@param event table  on_resource_depleted
function ResourceSource.on_resource_depleted(event)
  local entity = event.entity
  if state() == nil or not entity.valid then
    return
  end
  enqueue(entity.surface_index, math.floor(entity.position.x / 32), math.floor(entity.position.y / 32))
end

--- Re-scans the chunk a resource entity was added to or removed from by script.
---
--- Mods place or remove resources after a chunk has been charted and scanned; without
--- this the cache would never learn about either change. A destroyed entity raises
--- neither on_resource_depleted (that only fires for exhaustion) nor on_chunk_charted
--- (the chunk was already charted), so script_raised_destroy is the only signal the
--- cache gets -- confirmed against a live server that `event.entity` is still valid,
--- with a readable position and surface_index, at the time this handler runs.
--- Registered with a type filter so the handler is not called for ordinary building or
--- destruction.
---@param event table  on_built_entity, on_robot_built_entity, script_raised_built or
--- script_raised_destroy
function ResourceSource.on_resource_entity_changed(event)
  local entity = event.entity
  if state() == nil or entity == nil or not entity.valid or entity.type ~= "resource" then
    return
  end
  enqueue(entity.surface_index, math.floor(entity.position.x / 32), math.floor(entity.position.y / 32))
end

local SOURCE_LABEL = { "quidquid.source-resources" }
local NAMESPACE = "resources"

local function collect_resources()
  local resources = {}
  for _, prototype in pairs(prototypes.entity) do
    if prototype.type == "resource" then
      table.insert(resources, prototype)
    end
  end
  return resources
end

-- Built fresh per search rather than cached: prototypes never change within a session,
-- but this is a handful of entries and the cache lookup would cost more than rebuilding.
local function collect_localised_names()
  local localised_names = {}
  for _, prototype in ipairs(collect_resources()) do
    localised_names[prototype.name] = prototype.localised_name
  end
  return localised_names
end

-- The rich-text token for a resource candidate's surface: a planet icon when the
-- surface has one (the same "[planet=...]" tag vanilla's own Space Age locale uses,
-- rendered as rich text by lib/search_highlight.lua like the rest of this line), or
-- the plain surface name otherwise -- LuaSurface.planet is nil for a scripted surface
-- from another mod that has none.
local function surface_token(surface)
  if surface.planet ~= nil then
    return "[planet=" .. surface.planet.name .. "]"
  end
  return surface.name
end

-- Collects both the visible clusters and each of their surfaces' display tokens in
-- one pass, since this loop already has every relevant LuaSurface in hand -- a second
-- pass just to build the token map would walk the same surfaces again for nothing.
local function visible_clusters(player)
  local clusters = {}
  local surface_tokens = {}
  local resources = state()
  if resources == nil then
    return clusters, surface_tokens
  end
  local force = player.force
  for surface_index, store in pairs(resources.surfaces) do
    local surface = game.get_surface(surface_index)
    if surface ~= nil and surface.platform == nil then
      surface_tokens[surface_index] = surface_token(surface)
      for _, cluster in ipairs(ResourceClustering.all(store)) do
        for key in pairs(cluster.chunks) do
          local x, y = key:match("^(-?%d+),(-?%d+)$")
          if force.is_chunk_charted(surface, { x = tonumber(x), y = tonumber(y) }) then
            table.insert(clusters, cluster)
            break
          end
        end
      end
    end
  end
  return clusters, surface_tokens
end

-- One find_entities_filtered per candidate, with limit = 1 so the engine stops at the
-- first hit. Occupancy is checked over every candidate the source returns, not just
-- the 30 PaletteLogic.merge_candidates keeps, so the count matters -- see issue #174.
--
-- Every link of the chain -- the surface, this surface's store, this cluster -- is
-- guarded rather than indexed straight through: state() can be nil like every other
-- entry point here, and a surface's store or a specific cluster can legitimately be
-- gone by the time this runs (the background scan and the player both mutate it).
-- Any of those absences means "nothing to report", not a crash worth letting the
-- caller's pcall swallow for every candidate in the search.
local function is_occupied(candidate)
  local surface = game.get_surface(candidate.surface_index)
  if surface == nil then
    return false
  end
  local resources = state()
  if resources == nil then
    return false
  end
  local store = resources.surfaces[candidate.surface_index]
  if store == nil then
    return false
  end
  local cluster = store.clusters[candidate.id]
  if cluster == nil then
    return false
  end
  local drills = surface.find_entities_filtered({
    area = {
      left_top = { cluster.bounds.left, cluster.bounds.top },
      right_bottom = { cluster.bounds.right, cluster.bounds.bottom },
    },
    type = "mining-drill",
    limit = 1,
  })
  return #drills > 0
end

-- Mutates candidates in place, mirroring item_source's apply_annotations: the caller
-- runs this inside a pcall so one candidate's failure (an invalid surface mid-search,
-- say) logs rather than dropping every result this source found. This no longer sets
-- an `annotation` -- the occupied marker moved onto the muted second line instead (see
-- lib/resource_logic.lua), freeing the row's right end entirely. An unoccupied
-- candidate's secondary_text, built by ResourceLogic.build_candidates, is left as-is.
--
-- Rebuilding that second line here needs the same surface token and position
-- build_candidates used, but the candidate's public shape (see EXTENDING.md
-- "Candidates") has no field for the token, only the coordinates it already carries as
-- `position` (used for the pin and remote view). Rather than widen every resource
-- candidate with a token field only this function reads, the token is recovered from
-- the plain secondary_text build_candidates already wrote: it is always
-- "<token> (x, y)", so the text up to the last " (" is the token, unchanged since no
-- token this source produces contains that sequence itself.
local function mark_occupied(candidates)
  for _, candidate in ipairs(candidates) do
    if is_occupied(candidate) then
      local token = candidate.secondary_text:match("^(.*) %(")
      candidate.secondary_text = ResourceLogic.secondary_text(token, candidate.position, true)
    end
  end
end

local function search(query, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return {}
  end
  local translated_names = flib_dictionary.get(player_index, NAMESPACE) or {}
  local clusters, surface_tokens = visible_clusters(player)
  local candidates = ResourceLogic.build_candidates(
    query,
    clusters,
    player.locale,
    translated_names,
    collect_localised_names(),
    surface_tokens
  )
  local ok, err = pcall(mark_occupied, candidates)
  if not ok then
    log(("quidquid: source 'resources' occupancy marking failed: %s"):format(tostring(err)))
  end
  return candidates
end

--- Registers the resource-name dictionary with flib, for translated-name search.
---
--- Must run from on_init/on_configuration_changed, before the first on_tick -- see
--- control.lua and EXTENDING.md "Translated names".
function ResourceSource.register_dictionary()
  flib_dictionary.new(NAMESPACE)
  for _, prototype in ipairs(collect_resources()) do
    flib_dictionary.add(NAMESPACE, prototype.name, prototype.localised_name)
  end
end

--- Adds this source's remote interface and registers it with Quidquid.
function ResourceSource.register()
  remote.add_interface("quidquid.resource-source", { search = search })
  remote.call("quidquid", "register_source", {
    contract_version = 1,
    id = "resources",
    type = "resource",
    label = SOURCE_LABEL,
    -- "R" is uppercase because recipes hold "r". Prefix matching is case-sensitive --
    -- see EXTENDING.md "Definition" and spec/lib/registry_spec.lua.
    prefixes = { "resource", "R" },
    in_default_search = false,
    interface = "quidquid.resource-source",
  })
end

return ResourceSource
