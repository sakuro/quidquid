local fuzzy_match = require("lib.fuzzy_match")

describe("fuzzy_match", function()
  it("rejects an empty query", function()
    assert.is_nil(fuzzy_match("", "iron-plate"))
  end)

  it("matches a subsequence and returns codepoint positions", function()
    local score, positions = fuzzy_match("ipl", "iron-plate")

    assert.is_true(score ~= nil)
    assert.are.same({ 1, 6, 7 }, positions)
  end)

  it("rejects a query whose characters are out of order", function()
    assert.is_nil(fuzzy_match("ipl", "iron-lapte"))
  end)

  it("prefers consecutive matches", function()
    local direct_score = fuzzy_match("abc", "abc")
    local separated_score = fuzzy_match("abc", "a-b-c")

    assert.is_true(direct_score > separated_score)
  end)

  it("prefers word boundaries", function()
    local boundary_score = fuzzy_match("fb", "foo-bar")
    local interior_score = fuzzy_match("fb", "foobaz")

    assert.is_true(boundary_score > interior_score)
  end)

  it("operates on normalized Unicode codepoints", function()
    local score, positions = fuzzy_match("ベル", "ベルト")

    assert.is_true(score ~= nil)
    assert.are.same({ 1, 2 }, positions)
  end)

  it("returns no match for malformed UTF-8", function()
    assert.is_nil(fuzzy_match("a", "\255"))
  end)
end)
