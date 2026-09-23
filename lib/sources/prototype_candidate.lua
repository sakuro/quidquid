local api = require("lib.api")

local function build_candidates(
  candidate_type,
  icon_prefix,
  query,
  prototype_list,
  locale,
  translated_names,
  include_hidden
)
  local candidates = {}
  local matcher = api.matcher(query, locale)
  for _, prototype in ipairs(prototype_list) do
    if include_hidden or not prototype.hidden then
      local translated = translated_names[prototype.name]
      local match = matcher:match("prototype", prototype.name, {
        display = translated,
        internal = prototype.name,
      })
      if match ~= nil then
        table.insert(candidates, {
          type = candidate_type,
          id = prototype.name,
          label = prototype.localised_name,
          icon = icon_prefix .. "/" .. prototype.name,
          search_display_name = translated,
          search_internal_name = prototype.name,
          search_display_ranges = match.display_ranges,
          search_internal_ranges = match.internal_ranges,
          search_score = match.score,
        })
      end
    end
  end
  return candidates
end

return build_candidates
