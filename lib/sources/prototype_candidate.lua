local substring_match = require("lib.substring_match")

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
  for _, prototype in ipairs(prototype_list) do
    if include_hidden or not prototype.hidden then
      local matched = substring_match(query, prototype.name)
      if not matched then
        local translated = translation_cache:get(locale, prototype.name)
        matched = type(translated) == "string" and substring_match(query, translated)
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
