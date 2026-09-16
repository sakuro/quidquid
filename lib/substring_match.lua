local function substring_match(query, target)
  if query == "" then
    return false
  end

  return target:lower():find(query:lower(), 1, true) ~= nil
end

return substring_match
