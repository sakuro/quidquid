local api = require("lib.api")
local fuzzy_match = require("lib.fuzzy_match")
local normalization = require("lib.search_normalization")
local search_highlight = require("lib.search_highlight")

local function internal_score(query, target)
  local value = normalization.normalize(target)
  return (fuzzy_match(normalization.normalize(query), value))
end

local function display_match(query, target)
  local value, position_map = normalization.normalize(target)
  local score, positions = fuzzy_match(normalization.normalize(query), value)
  return score, search_highlight.positions_to_ranges(position_map, positions)
end

describe("api.matcher", function()
  it("scores an internal-name match the way fuzzy_match does", function()
    local matcher = api.matcher("iron")

    local match = matcher:match("spec", "iron-plate", { internal = "iron-plate" })

    assert.are.equal(internal_score("iron", "iron-plate"), match.score)
  end)

  it("returns nil when no field matches", function()
    local matcher = api.matcher("zzz")

    assert.is_nil(matcher:match("spec", "iron-plate", { internal = "iron-plate" }))
  end)

  it("rewards a display-name match so it outranks the same score on the internal name", function()
    local expected = display_match("iron", "Iron Plate")

    local match = api.matcher("iron"):match("spec", "iron-plate", { display = "Iron Plate" })

    assert.are.equal(expected + 0.5, match.score)
  end)

  it("reports the matched ranges of the winning field only", function()
    local _, expected_ranges = display_match("iron", "Iron Plate")

    local match = api.matcher("iron"):match("spec", "iron-plate", {
      display = "Iron Plate",
      internal = "iron-plate",
    })

    assert.are.same(expected_ranges, match.display_ranges)
    assert.are.same({}, match.internal_ranges)
  end)

  it("normalizes the query once, not once per entry", function()
    local original = normalization.normalize
    local query_normalizations = 0
    normalization.normalize = function(value)
      if value == "iron" then
        query_normalizations = query_normalizations + 1
      end
      return original(value)
    end

    local matcher = api.matcher("iron")
    matcher:match("spec", "iron-plate", { internal = "iron-plate" })
    matcher:match("spec", "iron-gear-wheel", { internal = "iron-gear-wheel" })
    normalization.normalize = original

    assert.are.equal(1, query_normalizations)
  end)

  it("keeps the internal match when it outscores the rewarded display one", function()
    local match = api.matcher("iron-plate"):match("spec", "iron-plate", {
      display = "Solid iron plate for building",
      internal = "iron-plate",
    })

    assert.are.equal(internal_score("iron-plate", "iron-plate"), match.score)
    assert.are.same({}, match.display_ranges)
  end)
end)

describe("api.forget", function()
  it("drops one entry's cached keys, so the next match normalizes it again", function()
    local matcher = api.matcher("iron")
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

describe("api.rich_text", function()
  local rich_text = require("lib.rich_text")

  it("exposes rich_text's searchable and map_ranges", function()
    assert.are.equal(rich_text.searchable, api.rich_text.searchable)
    assert.are.equal(rich_text.map_ranges, api.rich_text.map_ranges)
  end)

  it("does not expose icon_list_caption", function()
    assert.is_nil(api.rich_text.icon_list_caption)
  end)

  it("maps a match on a tag's text back to no highlight in the original", function()
    local text, origins = api.rich_text.searchable("[item=rail]Rail")
    local tag_start = text:find("rail", 1, true)

    assert.are.same({}, api.rich_text.map_ranges({ { start_byte = tag_start, end_byte = tag_start + 3 } }, origins))
  end)
end)

describe("api.run_action", function()
  it("is ActionRunner.run", function()
    assert.are.equal(require("lib.action_runner").run, api.run_action)
  end)
end)

describe("api.number_format", function()
  it("exposes number_format's suffixed", function()
    assert.are.equal(require("lib.number_format").suffixed, api.number_format.suffixed)
  end)
end)
