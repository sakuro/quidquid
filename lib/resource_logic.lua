local api = require("lib.api")
local NumberFormat = require("lib.number_format")

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

--- A patch's own second line: where it is, not what it's called.
---
--- Every patch of one resource shares the same prototype name, so putting that name
--- on the muted second line (as search_internal_name would) gives ten identical
--- lines for ten patches -- the one line that could distinguish them carries
--- nothing. The surface token plus the anchor's floored coordinates does distinguish
--- them, and the coordinates match the anchor used for the pin and remote view, so
--- what is shown is where the player actually lands.
---
--- A patch already worked by a mining drill is occupied -- a runtime fact this pure
--- module never learns on its own (see lib/sources/resource_source.lua, which calls
--- back in with `occupied` once it knows). The marker used to be a separate
--- `annotation` at the row's right end; it now lives here instead, right after the
--- coordinates, freeing the annotation area entirely. `search_highlight.highlight`
--- (lib/search_highlight.lua) wraps a plain second line in "[font=default]...[/font]",
--- but skips that wrapper for any value that is not a plain string -- so the occupied
--- form has to carry the identical font tags itself, as a LocalisedString, or an
--- occupied row's second line would render in a different font from every other
--- row's.
---@param surface_token string  the surface's display token, "[planet=x]" or a plain name
---@param position table  { x, y }, the candidate's own position
---@param occupied boolean|nil  true when a mining drill already works this patch;
--- false or nil for the plain, unoccupied form
---@return string|table  the plain string when unoccupied; a LocalisedString, already
--- carrying the plain form's own font wrapper, when occupied
function ResourceLogic.secondary_text(surface_token, position, occupied)
  local plain = ("%s (%d, %d)"):format(surface_token, math.floor(position.x), math.floor(position.y))
  if not occupied then
    return plain
  end
  return { "", "[font=default]", plain .. " ", { "quidquid.resource-occupied" }, "[/font]" }
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
---@param surface_tokens table  surface_index -> display token ("[planet=x]" or a plain
--- surface name), built by the caller from the LuaSurface it already has in hand; a
--- cluster whose surface has no entry falls back to the surface index itself
---@return table  candidates, richest first; see EXTENDING.md "Candidates"
function ResourceLogic.build_candidates(query, clusters, locale, translated_names, localised_names, surface_tokens)
  local candidates = {}
  local matcher = api.matcher(query, locale)
  surface_tokens = surface_tokens or {}
  for _, cluster in ipairs(clusters) do
    local translated = translated_names[cluster.resource_name]
    local match = matcher:match("resource", cluster.resource_name, {
      display = translated,
      internal = cluster.resource_name,
    })
    if match ~= nil then
      local position = richest_chunk_anchor(cluster.chunks)
      local surface_token = surface_tokens[cluster.surface_index] or tostring(cluster.surface_index)
      local amount_text = NumberFormat.suffixed(cluster.amount)
      -- The amount goes after the name, in both cases: appended directly when
      -- `translated` is a plain string (see the module comment on why that is safe
      -- for search_display_ranges), or spliced into a LocalisedString when only the
      -- prototype's localised_name is available.
      local label, search_display_name
      if translated ~= nil then
        label = translated .. " " .. amount_text
        search_display_name = label
      else
        label = { "", localised_names[cluster.resource_name], " ", amount_text }
      end
      table.insert(candidates, {
        type = "resource",
        id = cluster.id,
        resource_name = cluster.resource_name,
        surface_index = cluster.surface_index,
        amount = cluster.amount,
        position = position,
        label = label,
        icon = "entity/" .. cluster.resource_name,
        search_display_name = search_display_name,
        secondary_text = ResourceLogic.secondary_text(surface_token, position),
        search_display_ranges = match.display_ranges,
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
