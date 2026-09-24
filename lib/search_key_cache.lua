local normalization = require("lib.search_normalization")

local cache = {}

local function candidate_key(candidate_id)
  return type(candidate_id) .. "\0" .. tostring(candidate_id)
end

local function field_key(field, locale)
  return field .. "\0" .. (locale or "")
end

--- The normalized form of one entry's field, computing it on a miss.
---
--- The cache stores the raw value it normalized, the locale, and the normalization
--- rule version, and compares all three on every read -- so a renamed prototype, a
--- locale switch, or a rule change invalidates its own entry with no explicit
--- purge. Only an entry that disappears needs clear().
---@param namespace string
---@param candidate_id any  keyed by type and value, so 1 and "1" do not collide
---@param field string  "display" or "internal"
---@param locale string|nil
---@param raw_value string  returned as-is, with an empty map, when not a string
---@return string  the normalized value
---@return table|nil  position map, as lib.search_normalization returns it
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

--- Drops cached entries: one candidate's with both arguments, a whole namespace
--- with only the first, everything with neither.
---
--- Only reachability makes this necessary -- stale content invalidates itself on
--- read. An entry that can no longer be reached (a destroyed surface's, say) never
--- gets that read, so its keys would sit there for the rest of the session.
---@param namespace string|nil
---@param candidate_id any|nil
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
