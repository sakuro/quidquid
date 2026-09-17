local normalized_substring_match = require("lib.normalized_substring_match")
local normalization = require("lib.search_normalization")
local search_key_cache = require("lib.search_key_cache")

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
      local internal_key = search_key_cache.get("prototype", prototype.name, "internal", nil, prototype.name)
      local matched = normalized_substring_match(internal_query, internal_key)
      if not matched then
        local translated = translation_cache:get(locale, prototype.name)
        if type(translated) == "string" then
          local display_key = search_key_cache.get("prototype", prototype.name, "display", locale, translated)
          matched = normalized_substring_match(display_query, display_key)
        end
      end
      if matched then
        table.insert(candidates, {
          type = candidate_type,
          id = prototype.name,
          label = prototype.localised_name,
          icon = icon_prefix .. "/" .. prototype.name,
        })
      end
    end
  end
  return candidates
end

return build_candidates
