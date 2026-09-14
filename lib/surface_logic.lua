local substring_match = require("lib.substring_match")

local SurfaceLogic = {}

-- Descriptors contain only plain values, extracted for the current player's force.
function SurfaceLogic.is_visible(surface, include_hidden)
  local accessible = surface.kind == "planet" and surface.unlocked
    or surface.kind == "platform" and (surface.own or surface.friendly)
  return not not (accessible and (include_hidden or not surface.hidden))
end

function SurfaceLogic.build_candidates(query, surfaces, include_hidden)
  local candidates = {}
  for _, surface in ipairs(surfaces) do
    if SurfaceLogic.is_visible(surface, include_hidden)
      and (substring_match(query, surface.name)
        or (surface.search_name and substring_match(query, surface.search_name))) then
      local label = surface.label
      if surface.kind == "platform" and not surface.own then
        label = {"quidquid.surface-with-force", label, surface.force_name}
      end
      table.insert(candidates, {
        type = "surface", id = surface.index, label = label, icon = surface.icon,
      })
    end
  end
  table.sort(candidates, function(a, b) return a.id < b.id end)
  return candidates
end

return SurfaceLogic
