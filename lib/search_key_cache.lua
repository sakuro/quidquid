local normalization = require("lib.search_normalization")

local cache = {}

local function candidate_key(candidate_id)
  return type(candidate_id) .. "\0" .. tostring(candidate_id)
end

local function field_key(field, locale)
  return field .. "\0" .. (locale or "")
end

local function get(namespace, candidate_id, field, locale, raw_value)
  if type(raw_value) ~= "string" then
    return raw_value, {}
  end

  local namespace_cache = cache[namespace]
  if namespace_cache == nil then
    namespace_cache = {}
    cache[namespace] = namespace_cache
  end
  local id_key = candidate_key(candidate_id)
  local id_cache = namespace_cache[id_key]
  if id_cache == nil then
    id_cache = {}
    namespace_cache[id_key] = id_cache
  end

  local key = field_key(field, locale)
  local entry = id_cache[key]
  if
    entry ~= nil
    and entry.raw_value == raw_value
    and entry.locale == locale
    and entry.rule_version == normalization.rule_version
  then
    return entry.value, entry.position_map
  end

  local value, position_map = normalization.normalize(raw_value, field, locale)
  id_cache[key] = {
    raw_value = raw_value,
    locale = locale,
    rule_version = normalization.rule_version,
    value = value,
    position_map = position_map,
  }
  return value, position_map
end

-- clear(): drop the whole cache. clear(namespace): drop one namespace.
-- clear(namespace, candidate_id): drop just that candidate's entries, e.g. when
-- a surface is destroyed and its "surface" namespace entry becomes unreachable.
local function clear(namespace, candidate_id)
  if namespace == nil then
    cache = {}
    return
  end
  if candidate_id == nil then
    cache[namespace] = nil
    return
  end
  local namespace_cache = cache[namespace]
  if namespace_cache ~= nil then
    namespace_cache[candidate_key(candidate_id)] = nil
  end
end

return {
  get = get,
  clear = clear,
}
