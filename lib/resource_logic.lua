local api = require("lib.api")

local ResourceLogic = {}

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
---@return table  candidates, richest first; see EXTENDING.md "Candidates"
function ResourceLogic.build_candidates(query, clusters, locale, translated_names)
  local candidates = {}
  local matcher = api.matcher(query, locale)
  for _, cluster in ipairs(clusters) do
    local translated = translated_names[cluster.resource_name]
    local match = matcher:match("resource", cluster.resource_name, {
      display = translated,
      internal = cluster.resource_name,
    })
    if match ~= nil then
      local bounds = cluster.bounds
      table.insert(candidates, {
        type = "resource",
        id = cluster.id,
        resource_name = cluster.resource_name,
        surface_index = cluster.surface_index,
        amount = cluster.amount,
        position = {
          x = (bounds.left + bounds.right) / 2,
          y = (bounds.top + bounds.bottom) / 2,
        },
        label = translated or cluster.resource_name,
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
