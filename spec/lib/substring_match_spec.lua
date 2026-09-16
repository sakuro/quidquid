local substring_match = require("lib.substring_match")

describe("substring_match", function()
  it("matches an identical string", function()
    assert.is_true(substring_match("iron-plate", "iron-plate"))
  end)

  it("matches a substring anywhere in the target", function()
    assert.is_true(substring_match("iron", "iron-plate"))
    assert.is_true(substring_match("plate", "iron-plate"))
  end)

  it("matches punctuation literally", function()
    assert.is_true(substring_match("iron-", "iron-plate"))
    assert.is_false(substring_match("iron_", "iron-plate"))
  end)

  it("matches case-insensitively when the query is uppercase", function()
    assert.is_true(substring_match("IRON", "iron-plate"))
  end)

  it("matches case-insensitively when the target is uppercase", function()
    assert.is_true(substring_match("iron", "IRON-PLATE"))
  end)

  it("does not match a string that isn't present", function()
    assert.is_false(substring_match("copper", "iron-plate"))
  end)

  it("does not match non-consecutive characters", function()
    assert.is_false(substring_match("ipl", "iron-plate"))
  end)

  it("does not match an empty query", function()
    assert.is_false(substring_match("", "iron-plate"))
  end)

  it("does not match a query longer than the target", function()
    assert.is_false(substring_match("iron-plate-bar", "iron-plate"))
  end)

  it("matches identical non-ASCII text without normalizing it", function()
    assert.is_true(substring_match("café", "café"))
    assert.is_false(substring_match("cafe", "café"))
    assert.is_true(substring_match("ベルト", "搬送ベルト"))
    assert.is_false(substring_match("べると", "搬送ベルト"))
  end)
end)
