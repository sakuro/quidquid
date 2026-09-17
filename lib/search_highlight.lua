local DEFAULT_NORMAL_FONT = "default-large"
local DEFAULT_BOLD_FONT = "default-large-bold"

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
