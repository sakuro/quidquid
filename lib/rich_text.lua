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

return {
  mask_tags = mask_tags,
}
