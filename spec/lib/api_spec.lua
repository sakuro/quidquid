local api = require("lib.api")
local fuzzy_match = require("lib.fuzzy_match")
local normalization = require("lib.search_normalization")
local search_highlight = require("lib.search_highlight")

local function internal_score(query, target)
  local value = normalization.normalize(target, "internal", nil)
  return (fuzzy_match(normalization.normalize(query, "internal", nil), value))
end

local function display_match(query, target, locale)
  local value, position_map = normalization.normalize(target, "display", locale)
  local score, positions = fuzzy_match(normalization.normalize(query, "display", locale), value)
  return score, search_highlight.positions_to_ranges(position_map, positions)
end

describe("api.matcher", function()
  it("scores an internal-name match the way fuzzy_match does", function()
    local matcher = api.matcher("iron", "en")

    local match = matcher:match("spec", "iron-plate", { internal = "iron-plate" })

    assert.are.equal(internal_score("iron", "iron-plate"), match.score)
  end)

  it("returns nil when no field matches", function()
    local matcher = api.matcher("zzz", "en")

    assert.is_nil(matcher:match("spec", "iron-plate", { internal = "iron-plate" }))
  end)

  it("rewards a display-name match so it outranks the same score on the internal name", function()
    local expected = display_match("iron", "Iron Plate", "en")

    local match = api.matcher("iron", "en"):match("spec", "iron-plate", { display = "Iron Plate" })

    assert.are.equal(expected + 0.5, match.score)
  end)

  it("reports the matched ranges of the winning field only", function()
    local _, expected_ranges = display_match("iron", "Iron Plate", "en")

    local match = api.matcher("iron", "en"):match("spec", "iron-plate", {
      display = "Iron Plate",
      internal = "iron-plate",
    })

    assert.are.same(expected_ranges, match.display_ranges)
    assert.are.same({}, match.internal_ranges)
  end)

  it("normalizes the query once, not once per entry", function()
    local original = normalization.normalize
    local query_normalizations = 0
    normalization.normalize = function(value, ...)
      if value == "iron" then
        query_normalizations = query_normalizations + 1
      end
      return original(value, ...)
    end

    local matcher = api.matcher("iron", "en")
    matcher:match("spec", "iron-plate", { internal = "iron-plate" })
    matcher:match("spec", "iron-gear-wheel", { internal = "iron-gear-wheel" })
    normalization.normalize = original

    assert.are.equal(2, query_normalizations)
  end)

  it("keeps the internal match when it outscores the rewarded display one", function()
    local match = api.matcher("iron-plate", "en"):match("spec", "iron-plate", {
      display = "Solid iron plate for building",
      internal = "iron-plate",
    })

    assert.are.equal(internal_score("iron-plate", "iron-plate"), match.score)
    assert.are.same({}, match.display_ranges)
  end)
end)

describe("api.forget", function()
  it("drops one entry's cached keys so a renamed entry is normalized again", function()
    local matcher = api.matcher("iron", "en")
    matcher:match("spec-forget", "widget", { display = "Iron Plate" })

    api.forget("spec-forget", "widget")

    local original = normalization.normalize
    local normalizations = 0
    normalization.normalize = function(...)
      normalizations = normalizations + 1
      return original(...)
    end
    matcher:match("spec-forget", "widget", { display = "Iron Plate" })
    normalization.normalize = original

    assert.are.equal(1, normalizations)
  end)
end)
