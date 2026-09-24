local api = require("lib.api")

local ResourceLogic = {}

-- A geometric centre is not safe to hand to LuaPlayer.add_pin: resource entities sit at
-- tile centres (n + 0.5), so averaging a chunk's min and max entity coordinate on an
-- axis gives (i + j) / 2 + 0.5, which lands on another tile centre only when i + j is
-- even -- and on a bare tile BOUNDARY, inside no entity's collision box, when i + j is
-- odd. That parity is a per-axis coin-flip independent of patch shape, so it bit
-- convex, single-chunk patches as often as ring-shaped ones (confirmed in the field:
-- the engine's "no resource entity found at the given position" fires for exactly the
-- patches whose richest chunk spans an odd number of tiles on some axis). Anchoring on
-- an actual entity position instead -- recorded by ResourceClustering.group_chunk as
-- the chunk's `anchor` -- sidesteps the parity question entirely, since a real entity's
-- own position is always on ore. Ties -- equal amount -- are broken by chunk key,
-- ascending, so the result is stable across runs regardless of pairs() iteration order.
local function richest_chunk_anchor(chunks)
  local best_key, best_entry
  for key, entry in pairs(chunks) do
    if
      best_entry == nil
      or entry.amount > best_entry.amount
      or (entry.amount == best_entry.amount and key < best_key)
    then
      best_key, best_entry = key, entry
    end
  end
  return best_entry.anchor
end

--- Builds the resource source's candidates for one query.
---
--- Clusters of one resource all carry the same name and so the same match score.
--- PaletteLogic.merge_candidates breaks a score tie by arrival order, which for one
--- source is this array's order -- so sorting here by amount is what actually decides
--- the order a player sees, without bending search_score to carry it.
---@param query string
---@param clusters table  array of clusters, as lib.resource_clustering builds them
---@param locale string|nil  the player's locale, for display-name normalization
---@param translated_names table  resource name -> translated name, from flib's dictionary
---@param localised_names table  resource name -> LocalisedString, from the resource
--- prototypes; used as the label until a translated name arrives
---@return table  candidates, richest first; see EXTENDING.md "Candidates"
function ResourceLogic.build_candidates(query, clusters, locale, translated_names, localised_names)
  local candidates = {}
  local matcher = api.matcher(query, locale)
  for _, cluster in ipairs(clusters) do
    local translated = translated_names[cluster.resource_name]
    local match = matcher:match("resource", cluster.resource_name, {
      display = translated,
      internal = cluster.resource_name,
    })
    if match ~= nil then
      table.insert(candidates, {
        type = "resource",
        id = cluster.id,
        resource_name = cluster.resource_name,
        surface_index = cluster.surface_index,
        amount = cluster.amount,
        position = richest_chunk_anchor(cluster.chunks),
        label = translated or localised_names[cluster.resource_name],
        icon = "entity/" .. cluster.resource_name,
        search_display_name = translated,
        search_internal_name = cluster.resource_name,
        search_display_ranges = match.display_ranges,
        search_internal_ranges = match.internal_ranges,
        search_score = match.score,
      })
    end
  end
  table.sort(candidates, function(a, b)
    if a.amount ~= b.amount then
      return a.amount > b.amount
    end
    return a.id < b.id
  end)
  return candidates
end

return ResourceLogic
