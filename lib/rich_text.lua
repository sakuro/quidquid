--- Replaces rich-text tags with spaces, preserving their byte length.
---
--- Equal length is the whole point: a masked value is what gets normalized and
--- matched, while the original is what gets displayed, so the position map only
--- lines up if masking moves no byte. Spaces rather than removal, for the same
--- reason.
---@param value string  returned unchanged when not a string
---@return string
local function mask_tags(value)
  if type(value) ~= "string" then
    return value
  end

  local result = {}
  local next_byte = 1
  while next_byte <= #value do
    local start_byte, end_byte = value:find("%b[]", next_byte)
    if start_byte == nil then
      table.insert(result, value:sub(next_byte))
      break
    end
    if next_byte < start_byte then
      table.insert(result, value:sub(next_byte, start_byte - 1))
    end
    table.insert(result, string.rep(" ", end_byte - start_byte + 1))
    next_byte = end_byte + 1
  end
  return table.concat(result)
end

--- Builds a capped, separator-joined list of rich-text icons as a LocalisedString.
---
--- Every entry is an untranslated rich-text tag, so the list is concatenated into a
--- single string rather than built as a LocalisedString array. That makes it cost
--- exactly one parameter in whatever LocalisedString it is embedded into, however
--- many items it lists. Each call site used to build the array itself, and
--- Factorio's hard 20-parameters-per-array limit was hit in production once an item
--- list grew past ~10 entries.
---@param items table
---@param icon_fn function  (item) -> rich-text tag string
---@param limit number  entries shown before the "N more" entry takes over
---@param more_locale_key string  takes the remaining count as its one parameter
---@param separator string|nil  defaults to ", "
---@return table  a LocalisedString
local function icon_list_caption(items, icon_fn, limit, more_locale_key, separator)
  separator = separator or ", "
  local truncated = #items > limit
  local shown_count = truncated and limit or #items
  local icons = {}
  for i = 1, shown_count do
    table.insert(icons, icon_fn(items[i]))
  end
  local joined = table.concat(icons, separator)
  local result = { "", truncated and (joined .. separator) or joined }
  if truncated then
    table.insert(result, { more_locale_key, #items - shown_count })
  end
  return result
end

return {
  mask_tags = mask_tags,
  icon_list_caption = icon_list_caption,
}
