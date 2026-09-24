local api = require("lib.api")

local ResourceLogic = {}

-- Anchoring on the bounding box's centre routinely lands off the ore, because clusters
-- merge on chunk adjacency alone and never split (see lib.resource_clustering): two
-- patches a chunk apart merge and the centre falls in the gap, an L-shaped or
-- ring-shaped patch does the same, and a patch mined out in the middle keeps its old
-- bounds. The richest chunk's own left/top/right/bottom are the min/max of that chunk's
-- actual entity positions, so its centre is always inside real ore. Ties -- equal
-- amount -- are broken by chunk key, ascending, so the result is stable across runs
-- regardless of pairs() iteration order.
local function richest_chunk_centre(chunks)
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
  return {
    x = (best_entry.left + best_entry.right) / 2,
    y = (best_entry.top + best_entry.bottom) / 2,
  }
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
        position = richest_chunk_centre(cluster.chunks),
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
