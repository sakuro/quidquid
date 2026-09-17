local normalized_substring_match = require("lib.normalized_substring_match")
local normalization = require("lib.search_normalization")
local search_key_cache = require("lib.search_key_cache")

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
    local matched = false
    if surface.search_name then
      local display_key = search_key_cache.get("surface", surface.index, "display", locale, surface.search_name)
      matched = normalized_substring_match(display_query, display_key)
    end
    if surface.kind ~= "platform" then
      local internal_key = search_key_cache.get("surface", surface.index, "internal", nil, surface.name)
      matched = matched or normalized_substring_match(internal_query, internal_key)
    end
    if SurfaceLogic.is_visible(surface, include_hidden) and matched then
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
