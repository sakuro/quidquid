local fuzzy_match = require("lib.fuzzy_match")
local normalization = require("lib.search_normalization")
local search_key_cache = require("lib.search_key_cache")
local search_highlight = require("lib.search_highlight")
local rich_text = require("lib.rich_text")

local LOCALIZED_NAME_BONUS = 0.5

local SurfaceLogic = {}

-- Descriptors contain only plain values, extracted for the current player's force.
function SurfaceLogic.is_visible(surface, include_hidden)
  local accessible = surface.kind == "planet" or surface.kind == "platform" and (surface.own or surface.friendly)
  return not not (accessible and (include_hidden or not surface.hidden))
end

function SurfaceLogic.can_open_remote_view(surface, include_hidden)
  return SurfaceLogic.is_visible(surface, include_hidden)
    and surface.generated ~= false
    and (surface.kind ~= "planet" or surface.unlocked == true)
end

function SurfaceLogic.build_candidates(query, surfaces, include_hidden, locale)
  local candidates = {}
  local internal_query = normalization.normalize(query, "internal", nil)
  local display_query = normalization.normalize(query, "display", locale)
  for _, surface in ipairs(surfaces) do
    local best
    if surface.search_name then
      local search_name = surface.search_name
      if surface.kind == "platform" then
        search_name = rich_text.mask_tags(search_name)
      end
      local display_key, display_position_map =
        search_key_cache.get("surface", surface.index, "display", locale, search_name)
      local display_score, display_positions = fuzzy_match(display_query, display_key)
      if display_score ~= nil then
        best = {
          score = display_score + LOCALIZED_NAME_BONUS,
          field = "localized_name",
          positions = display_positions,
          ranges = search_highlight.positions_to_ranges(display_position_map, display_positions),
        }
      end
    end
    if surface.kind ~= "platform" then
      local internal_key, internal_position_map =
        search_key_cache.get("surface", surface.index, "internal", nil, surface.name)
      local internal_score, internal_positions = fuzzy_match(internal_query, internal_key)
      if internal_score ~= nil and (best == nil or internal_score > best.score) then
        best = {
          score = internal_score,
          field = "internal_name",
          positions = internal_positions,
          ranges = search_highlight.positions_to_ranges(internal_position_map, internal_positions),
        }
      end
    end
    if SurfaceLogic.is_visible(surface, include_hidden) and best ~= nil then
      local label = surface.label
      if surface.kind == "platform" and not surface.own then
        label = { "quidquid.surface-with-force", label, surface.force_name }
      end
      table.insert(candidates, {
        type = "surface",
        id = surface.index,
        planet_name = surface.planet_name,
        label = label,
        icon = surface.icon,
        search_display_name = type(surface.search_name) == "string" and surface.search_name or nil,
        search_internal_name = surface.kind ~= "platform" and surface.name or nil,
        search_display_ranges = best.field == "localized_name" and best.ranges or {},
        search_internal_ranges = best.field == "internal_name" and best.ranges or {},
        search_score = best.score,
        search_field = best.field,
        search_positions = best.positions,
      })
    end
  end
  table.sort(candidates, function(a, b)
    if type(a.id) ~= type(b.id) then
      return tostring(a.id) < tostring(b.id)
    end
    return a.id < b.id
  end)
  return candidates
end

return SurfaceLogic
