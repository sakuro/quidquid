local api = require("lib.api")

--- Builds candidates for a flat prototype list, shared by the item, fluid and recipe
--- sources.
---
--- Those three differ only in their candidate type and icon prefix: each matches a
--- translated display name against the untranslated prototype name, and each hides
--- hidden prototypes unless the player asked for them. A source with anything else to
--- say about a candidate (a count, a research state) adds it after this returns.
---@param candidate_type string  the source's own type, as registered
---@param icon_prefix string  rich-text tag type, e.g. "item" for [item=iron-plate]
---@param query string
---@param prototype_list table  array of prototypes with .name, .localised_name, .hidden
---@param locale string|nil  the player's locale, for display-name normalization
---@param translated_names table  prototype name -> translated name, from flib's dictionary
---@param include_hidden boolean  the player's include-hidden setting
---@return table  candidates; see EXTENDING.md "Candidates"
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
