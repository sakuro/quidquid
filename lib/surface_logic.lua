local api = require("lib.api")
local rich_text = require("lib.rich_text")

local SurfaceLogic = {}

--- True when a surface should appear in search results at all.
---
--- A planet always qualifies; a platform only if it is the force's own or a
--- friendly one. Descriptors carry plain values only, extracted by the caller for
--- the current player's force.
---@param descriptor table  { kind, own, friendly, hidden, ... }
---@param include_hidden boolean  the player's include-hidden setting
---@return boolean
function SurfaceLogic.is_visible(descriptor, include_hidden)
  local accessible = descriptor.kind == "planet"
    or descriptor.kind == "platform" and (descriptor.own or descriptor.friendly)
  return not not (accessible and (include_hidden or not descriptor.hidden))
end

--- Whether remote view can open this surface, and why not when it can't.
---
--- "Not unlocked" is checked before "not visited": a locked planet is necessarily
--- unvisited too, and not being unlocked is the more actionable reason to report.
--- An invisible surface gets no locale key at all -- it shouldn't be reachable from
--- a search result in the first place, so it isn't worth a message.
---@param descriptor table  { kind, unlocked, generated, ... }
---@param include_hidden boolean
---@return boolean
---@return string|nil  locale key explaining a false, nil when none is worth showing
function SurfaceLogic.remote_view_availability(descriptor, include_hidden)
  if not SurfaceLogic.is_visible(descriptor, include_hidden) then
    return false, nil
  end
  -- Checked before "not visited": a locked planet is necessarily unvisited too,
  -- and "not unlocked" is the more actionable reason to report.
  if descriptor.kind == "planet" and descriptor.unlocked ~= true then
    return false, "quidquid.action-open-remote-view-not-unlocked"
  end
  if descriptor.generated == false then
    return false, "quidquid.action-open-remote-view-not-visited"
  end
  return true, nil
end

--- Builds the surface source's candidates for one query.
---
--- Scored through lib.api like any other source, so surfaces rank against items and
--- recipes on the same scale.
---@param query string
---@param descriptors table  array of plain-value surface descriptors
---@param include_hidden boolean
---@param locale string|nil  the player's locale, for display-name normalization
---@return table  candidates, sorted by id; see EXTENDING.md "Candidates"
function SurfaceLogic.build_candidates(query, descriptors, include_hidden, locale)
  local candidates = {}
  local matcher = api.matcher(query, locale)
  for _, descriptor in ipairs(descriptors) do
    -- A platform's name is player-written and can carry rich text tags, which are
    -- masked out before matching (see README, "Surfaces"). Its
    -- prototype name is meaningless to search, so only planets match on one.
    local search_name = descriptor.search_name
    if search_name and descriptor.kind == "platform" then
      search_name = rich_text.mask_tags(search_name)
    end
    local match = matcher:match("surface", descriptor.id, {
      display = search_name,
      internal = descriptor.kind ~= "platform" and descriptor.name or nil,
    })
    if SurfaceLogic.is_visible(descriptor, include_hidden) and match ~= nil then
      local label = descriptor.label
      if descriptor.kind == "platform" and not descriptor.own then
        label = { "quidquid.surface-with-force", label, descriptor.force_name }
      end
      table.insert(candidates, {
        type = "surface",
        id = descriptor.id,
        planet_name = descriptor.planet_name,
        label = label,
        icon = descriptor.icon,
        search_display_name = type(descriptor.search_name) == "string" and descriptor.search_name or nil,
        search_internal_name = descriptor.kind ~= "platform" and descriptor.name or nil,
        search_display_ranges = match.display_ranges,
        search_internal_ranges = match.internal_ranges,
        search_score = match.score,
      })
    end
  end
  -- This order only ever surfaces as a tiebreak: Palette.search_all_sources
  -- feeds every source's candidates through PaletteLogic.merge_candidates,
  -- which re-sorts everything by search_score. Every id is a unique string --
  -- a surface's name, or an ungenerated planet's -- so a plain comparison
  -- suffices.
  table.sort(candidates, function(a, b)
    return a.id < b.id
  end)
  return candidates
end

return SurfaceLogic
