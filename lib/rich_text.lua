-- Replace rich-text tags with spaces while preserving their byte length. This keeps
-- normalized position maps aligned with the original value used for display.
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

-- Builds a plain-text, comma-separated list of rich-text tags (via icon_fn
-- per item), capped at `limit` entries with a trailing "N more" locale
-- entry (more_key) when there are more. Every entry is an untranslated
-- rich-text tag, so the list itself is built as a single concatenated
-- string -- not a LocalisedString array -- meaning it costs exactly one
-- parameter in whatever LocalisedString it's embedded into, regardless of
-- how many items it lists. (A LocalisedString array used to be built here
-- directly at each call site; Factorio's hard 20-parameters-per-array limit
-- was hit in production once an item list grew past ~10 entries.)
local function joined_list(items, icon_fn, limit, more_key)
  local truncated = #items > limit
  local shown_count = truncated and limit or #items
  local icons = {}
  for i = 1, shown_count do
    table.insert(icons, icon_fn(items[i]))
  end
  local result = { "", table.concat(icons, ", ") }
  if truncated then
    table.insert(result, { more_key, #items - shown_count })
  end
  return result
end

return {
  mask_tags = mask_tags,
  joined_list = joined_list,
}
