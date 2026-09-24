-- The one module other mods may require; see EXTENDING.md "Scoring". Everything
-- else under lib/ is internal.
--
-- Factorio resolves a require path against the root of the mod that called
-- require, not the file's own mod, so these siblings have to be named absolutely
-- for this file to load from another mod at all (flib does the same). Inside
-- Quidquid that means lib.search_key_cache must be reached through here and never
-- required directly, or its cache would exist twice under two package.loaded keys.
local fuzzy_match = require("__quidquid__.lib.fuzzy_match")
local normalization = require("__quidquid__.lib.search_normalization")
local search_highlight = require("__quidquid__.lib.search_highlight")
local search_key_cache = require("__quidquid__.lib.search_key_cache")

-- A display-name hit outranks an internal-name hit of the same raw score: the name
-- the player reads is the one they meant to type.
local DISPLAY_NAME_BONUS = 0.5

local Matcher = {}
Matcher.__index = Matcher

local function field_match(namespace, id, field, locale, query, raw_value)
  if type(raw_value) ~= "string" then
    return nil
  end
  local target, position_map = search_key_cache.get(namespace, id, field, locale, raw_value)
  local score, positions = fuzzy_match(query, target)
  if score == nil then
    return nil
  end
  return { score = score, ranges = search_highlight.positions_to_ranges(position_map, positions) }
end

--- Scores one entry's names against the matcher's query.
---
--- Returns nil when neither field matches. `namespace` and `id` key the cache of
--- normalized names, so a source picks a namespace of its own and an id stable for
--- the entry; see EXTENDING.md "Scoring".
---@param namespace string
---@param id string
---@param fields table  { display = string|nil, internal = string|nil }; either may be omitted
---@return table|nil  { score, display_ranges, internal_ranges } in the shape candidate fields expect
function Matcher:match(namespace, id, fields)
  local best_field = nil
  local best = field_match(namespace, id, "display", self.locale, self.display_query, fields.display)
  if best ~= nil then
    best_field = "display"
    best.score = best.score + DISPLAY_NAME_BONUS
  end

  local internal = field_match(namespace, id, "internal", nil, self.internal_query, fields.internal)
  -- Strictly greater, so a tie keeps the display match.
  if internal ~= nil and (best == nil or internal.score > best.score) then
    best_field = "internal"
    best = internal
  end

  if best == nil then
    return nil
  end
  return {
    score = best.score,
    display_ranges = best_field == "display" and best.ranges or {},
    internal_ranges = best_field == "internal" and best.ranges or {},
  }
end

--- A matcher for one query, to score every entry of a search against.
---
--- The query is normalized once here rather than per entry: `locale` picks the
--- normalization for display names, which differs from the internal-name one.
---@param query string
---@param locale string|nil  the player's locale, or nil to score internal names only
---@return table  a matcher, with :match(namespace, id, fields)
local function matcher(query, locale)
  return setmetatable({
    internal_query = normalization.normalize(query, "internal", nil),
    display_query = normalization.normalize(query, "display", locale),
    locale = locale,
  }, Matcher)
end

--- Drops cached normalizations: one entry with `id`, a whole `namespace` without
--- it, everything with neither.
---
--- This is about releasing memory, not correctness -- a renamed entry
--- re-normalizes on its own, because the cache stores the raw value it normalized
--- and compares it on every read. An entry that goes away has no such next read,
--- so without this its keys sit there for the rest of the session.
---@param namespace string|nil
---@param id string|nil
local function forget(namespace, id)
  search_key_cache.clear(namespace, id)
end

return {
  matcher = matcher,
  forget = forget,
}
