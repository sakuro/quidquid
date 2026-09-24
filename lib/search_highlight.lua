local DEFAULT_NORMAL_FONT = "default-large"
local DEFAULT_BOLD_FONT = "default-large-bold"

--- Turns matched code-point positions into byte ranges in the original value.
---
--- A position with no entry in the map is dropped rather than guessed at: it came
--- from a normalization step that added a code point the original value has no
--- bytes for (see lib.search_normalization).
---@param position_map table|nil
---@param positions table|nil
---@return table  array of { start_byte, end_byte }, empty when nothing maps
local function positions_to_ranges(position_map, positions)
  local ranges = {}
  for _, position in ipairs(positions or {}) do
    local range = position_map and position_map[position]
    if range ~= nil then
      table.insert(ranges, { start_byte = range.start_byte, end_byte = range.end_byte })
    end
  end
  return ranges
end

local function sorted_merged_ranges(ranges, value_length)
  local sorted = {}
  for _, range in ipairs(ranges or {}) do
    local start_byte = math.max(1, range.start_byte)
    local end_byte = math.min(value_length, range.end_byte)
    if start_byte <= end_byte then
      table.insert(sorted, { start_byte = start_byte, end_byte = end_byte })
    end
  end
  table.sort(sorted, function(a, b)
    return a.start_byte < b.start_byte
  end)

  local merged = {}
  for _, range in ipairs(sorted) do
    local previous = merged[#merged]
    if previous ~= nil and range.start_byte <= previous.end_byte + 1 then
      previous.end_byte = math.max(previous.end_byte, range.end_byte)
    else
      table.insert(merged, range)
    end
  end
  return merged
end

--- Wraps a value in font tags, bolding the matched ranges.
---
--- The whole value is wrapped, not just the matches: a label with no tags at all
--- would render in the style's own font and jump in size next to a highlighted one.
--- Ranges are clamped, sorted and merged first, so overlapping or out-of-bounds
--- input from a source cannot produce interleaved tags.
---@param value string  returned unchanged when not a string
---@param ranges table|nil  byte ranges to bold; nil or empty bolds nothing
---@param normal_font string|nil  defaults to default-large
---@param bold_font string|nil  defaults to default-large-bold
---@return string
local function highlight(value, ranges, normal_font, bold_font)
  if type(value) ~= "string" or ranges == nil or #ranges == 0 then
    if type(value) ~= "string" then
      return value
    end
    return "[font=" .. (normal_font or DEFAULT_NORMAL_FONT) .. "]" .. value .. "[/font]"
  end

  local merged = sorted_merged_ranges(ranges, #value)
  if #merged == 0 then
    return "[font=" .. (normal_font or DEFAULT_NORMAL_FONT) .. "]" .. value .. "[/font]"
  end

  normal_font = normal_font or DEFAULT_NORMAL_FONT
  bold_font = bold_font or DEFAULT_BOLD_FONT
  local result = {}
  local next_byte = 1
  for _, range in ipairs(merged) do
    if next_byte < range.start_byte then
      table.insert(result, "[font=" .. normal_font .. "]")
      table.insert(result, value:sub(next_byte, range.start_byte - 1))
      table.insert(result, "[/font]")
    end
    table.insert(result, "[font=" .. bold_font .. "]")
    table.insert(result, value:sub(range.start_byte, range.end_byte))
    table.insert(result, "[/font]")
    next_byte = range.end_byte + 1
  end
  if next_byte <= #value then
    table.insert(result, "[font=" .. normal_font .. "]")
    table.insert(result, value:sub(next_byte))
    table.insert(result, "[/font]")
  end
  return table.concat(result)
end

return {
  positions_to_ranges = positions_to_ranges,
  highlight = highlight,
}
