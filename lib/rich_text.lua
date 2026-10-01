-- Tags whose text never helps a search: formatting, a map position, a whole
-- blueprint string (which would fuzzy-match nearly any query).
local ERASED_TAG_NAMES = { color = true, font = true, gps = true, ["special-item"] = true }
local ERASED_CLOSERS = { ["/color"] = true, ["/font"] = true, [".color"] = true, [".font"] = true }

local function tag_text(inner)
  if ERASED_CLOSERS[inner] then
    return ""
  end
  local name, value = inner:match("^([^=]*)=(.*)$")
  if name == nil then
    return inner
  end
  if ERASED_TAG_NAMES[name] then
    return ""
  end
  if name == "tooltip" then
    return (value:match("^[^,]*"))
  end
  value = value:gsub(",quality=[^,]*", "")
  -- A sprite path's class ("item/", "item.") names no entry the player would type.
  return (value:match("[^/.]*$"))
end

--- The text a search should see in a value that may carry rich text tags.
---
--- Tags stay searchable by what they name -- `[item=rail]` reads as `rail` -- because
--- player-written names use icons in place of words. The result is shorter than the
--- original, so each byte records where it came from; tag-derived bytes record false,
--- which keeps them out of highlighting (the player sees an icon there, not text).
--- Tag text is set off by spaces so it neither merges with its neighbours into one
--- word nor loses the matcher's word-boundary bonus.
---@param value string
---@return string  the searchable text
---@return table  origins: original byte index per searchable byte, or false
local function searchable(value)
  local bytes = {}
  local origins = {}
  local function push(text, origin_start)
    for i = 1, #text do
      table.insert(bytes, text:sub(i, i))
      table.insert(origins, origin_start ~= nil and (origin_start + i - 1) or false)
    end
  end

  local pending_space = false
  local next_byte = 1
  while next_byte <= #value do
    local start_byte, end_byte = value:find("%b[]", next_byte)
    local plain_end = start_byte ~= nil and (start_byte - 1) or #value
    if next_byte <= plain_end then
      local plain = value:sub(next_byte, plain_end)
      if pending_space and plain:sub(1, 1) ~= " " then
        push(" ")
      end
      pending_space = false
      push(plain, next_byte)
    end
    if start_byte == nil then
      break
    end
    local text = tag_text(value:sub(start_byte + 1, end_byte - 1))
    if text ~= "" then
      if #bytes > 0 and bytes[#bytes] ~= " " then
        push(" ")
      end
      push(text)
      pending_space = true
    end
    next_byte = end_byte + 1
  end
  return table.concat(bytes), origins
end

--- Maps match ranges over `searchable`'s text back onto the original value.
---
--- Tag-derived bytes are dropped, and a range is split wherever the original bytes
--- stop being contiguous, so a highlight never lands inside a tag.
---@param ranges table|nil  array of { start_byte, end_byte } over the searchable text
---@param origins table  as returned by `searchable`
---@return table  array of { start_byte, end_byte } over the original value
local function map_ranges(ranges, origins)
  local mapped = {}
  for _, range in ipairs(ranges or {}) do
    local current = nil
    for i = range.start_byte, range.end_byte do
      local origin = origins[i]
      if origin and current ~= nil and origin == current.end_byte + 1 then
        current.end_byte = origin
      elseif origin then
        current = { start_byte = origin, end_byte = origin }
        table.insert(mapped, current)
      else
        current = nil
      end
    end
  end
  return mapped
end

--- Builds a capped, separator-joined list of rich-text icons as a LocalisedString.
---
--- Every entry is an untranslated rich-text tag, so the list is concatenated into a
--- single string rather than built as a LocalisedString array. That makes it cost
--- exactly one parameter in whatever LocalisedString it is embedded into, however
--- many items it lists. As an array, a list of more than ~10 entries hits Factorio's
--- hard limit of 20 parameters per array, which has happened in production.
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
  searchable = searchable,
  map_ranges = map_ranges,
  icon_list_caption = icon_list_caption,
}
