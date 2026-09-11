local substring_match = require("lib.substring_match")

local ItemSource = {}

function ItemSource.build_candidates(query, items, locale, translation_cache, include_hidden)
  local candidates = {}
  for _, item in ipairs(items) do
    if include_hidden or not item.hidden then
      local matched = substring_match(query, item.name)
      if not matched then
        local translated = translation_cache:get(locale, item.name)
        matched = type(translated) == "string" and substring_match(query, translated)
      end
      if matched then
        table.insert(candidates, {
          type = "item", id = item.name, label = item.localised_name, icon = "item/" .. item.name,
        })
      end
    end
  end
  return candidates
end

return ItemSource
