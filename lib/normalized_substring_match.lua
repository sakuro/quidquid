local function normalized_substring_match(query_key, target_key)
  if query_key == "" or type(target_key) ~= "string" then
    return false
  end
  return target_key:find(query_key, 1, true) ~= nil
end

return normalized_substring_match
