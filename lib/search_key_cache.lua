local normalization = require("lib.search_normalization")

local cache = {}

local function identity(namespace, candidate_id, field, locale)
  return table.concat({
    namespace,
    type(candidate_id),
    tostring(candidate_id),
    field,
    locale or "",
  }, "\0")
end

local function get(namespace, candidate_id, field, locale, raw_value)
  if type(raw_value) ~= "string" then
    return raw_value, {}
  end
  local key = identity(namespace, candidate_id, field, locale)
  local entry = cache[key]
  if
    entry ~= nil
    and entry.raw_value == raw_value
    and entry.locale == locale
    and entry.rule_version == normalization.rule_version
  then
    return entry.value, entry.position_map
  end
  local value, position_map = normalization.normalize(raw_value, field, locale)
  cache[key] = {
    raw_value = raw_value,
    locale = locale,
    rule_version = normalization.rule_version,
    value = value,
    position_map = position_map,
  }
  return value, position_map
end

local function clear()
  cache = {}
end

return {
  get = get,
  clear = clear,
}
