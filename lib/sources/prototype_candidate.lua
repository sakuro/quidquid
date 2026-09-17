local fuzzy_match = require("lib.fuzzy_match")
local normalization = require("lib.search_normalization")
local search_key_cache = require("lib.search_key_cache")
local search_highlight = require("lib.search_highlight")

local LOCALIZED_NAME_BONUS = 0.5

local function select_match(best, score, field, positions, position_map)
  if score == nil then
    return best
  end
  if field == "localized_name" then
    score = score + LOCALIZED_NAME_BONUS
  end
  if best == nil or score > best.score or (score == best.score and field == "localized_name") then
    return {
      score = score,
      field = field,
      positions = positions,
      ranges = search_highlight.positions_to_ranges(position_map, positions),
    }
  end
  return best
end

local function build_candidates(
  candidate_type,
  icon_prefix,
  query,
  prototype_list,
  locale,
  translation_cache,
  include_hidden
)
  local candidates = {}
  local internal_query = normalization.normalize(query, "internal", nil)
  local display_query = normalization.normalize(query, "display", locale)
  for _, prototype in ipairs(prototype_list) do
    if include_hidden or not prototype.hidden then
      local best
      local internal_key, internal_position_map =
        search_key_cache.get("prototype", prototype.name, "internal", nil, prototype.name)
      local internal_score, internal_positions = fuzzy_match(internal_query, internal_key)
      best = select_match(best, internal_score, "internal_name", internal_positions, internal_position_map)

      local translated = translation_cache:get(locale, prototype.name)
      if type(translated) == "string" then
        local display_key, display_position_map =
          search_key_cache.get("prototype", prototype.name, "display", locale, translated)
        local display_score, display_positions = fuzzy_match(display_query, display_key)
        best = select_match(best, display_score, "localized_name", display_positions, display_position_map)
      end
      if best ~= nil then
        table.insert(candidates, {
          type = candidate_type,
          id = prototype.name,
          label = prototype.localised_name,
          icon = icon_prefix .. "/" .. prototype.name,
          search_display_name = translated,
          search_internal_name = prototype.name,
          search_display_ranges = best.field == "localized_name" and best.ranges or {},
          search_internal_ranges = best.field == "internal_name" and best.ranges or {},
          search_score = best.score,
          search_field = best.field,
          search_positions = best.positions,
        })
      end
    end
  end
  return candidates
end

return build_candidates
