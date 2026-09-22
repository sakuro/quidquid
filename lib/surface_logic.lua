local fuzzy_match = require("lib.fuzzy_match")
local normalization = require("lib.search_normalization")
local search_key_cache = require("lib.search_key_cache")
local search_highlight = require("lib.search_highlight")
local rich_text = require("lib.rich_text")

local DISPLAY_NAME_BONUS = 0.5

local SurfaceLogic = {}

-- Descriptors contain only plain values, extracted for the current player's force.
function SurfaceLogic.is_visible(descriptor, include_hidden)
  local accessible = descriptor.kind == "planet"
    or descriptor.kind == "platform" and (descriptor.own or descriptor.friendly)
  return not not (accessible and (include_hidden or not descriptor.hidden))
end

-- Returns true, or false plus a locale key explaining why remote view isn't
-- available: not yet visited (never generated), or -- for a planet specifically --
-- not unlocked by the force. nil for a surface that isn't independently visible in
-- the first place (own/friendly/hidden rules); that state shouldn't be reachable
-- from a search result at all, so it's not worth a message.
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

function SurfaceLogic.build_candidates(query, descriptors, include_hidden, locale)
  local candidates = {}
  local internal_query = normalization.normalize(query, "internal", nil)
  local display_query = normalization.normalize(query, "display", locale)
  for _, descriptor in ipairs(descriptors) do
    local best
    if descriptor.search_name then
      local search_name = descriptor.search_name
      if descriptor.kind == "platform" then
        search_name = rich_text.mask_tags(search_name)
      end
      local display_target, display_position_map =
        search_key_cache.get("surface", descriptor.id, "display", locale, search_name)
      local display_score, display_positions = fuzzy_match(display_query, display_target)
      if display_score ~= nil then
        best = {
          score = display_score + DISPLAY_NAME_BONUS,
          field = "display",
          positions = display_positions,
          ranges = search_highlight.positions_to_ranges(display_position_map, display_positions),
        }
      end
    end
    if descriptor.kind ~= "platform" then
      local internal_target, internal_position_map =
        search_key_cache.get("surface", descriptor.id, "internal", nil, descriptor.name)
      local internal_score, internal_positions = fuzzy_match(internal_query, internal_target)
      if internal_score ~= nil and (best == nil or internal_score > best.score) then
        best = {
          score = internal_score,
          field = "internal",
          positions = internal_positions,
          ranges = search_highlight.positions_to_ranges(internal_position_map, internal_positions),
        }
      end
    end
    if SurfaceLogic.is_visible(descriptor, include_hidden) and best ~= nil then
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
        search_display_ranges = best.field == "display" and best.ranges or {},
        search_internal_ranges = best.field == "internal" and best.ranges or {},
        search_score = best.score,
      })
    end
  end
  -- This order only ever surfaces as a tiebreak: Palette.search_all_sources
  -- feeds every source's candidates through PaletteLogic.merge_candidates,
  -- which re-sorts everything by search_score. id is always a unique string
  -- now, so a plain comparison suffices -- no more mixing a generated
  -- surface's numeric index against an ungenerated planet's name.
  table.sort(candidates, function(a, b)
    return a.id < b.id
  end)
  return candidates
end

return SurfaceLogic
