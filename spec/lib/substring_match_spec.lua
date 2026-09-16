local substring_match = require("lib.substring_match")

describe("substring_match", function()
  it("matches an identical string", function()
    assert.is_true(substring_match("iron-plate", "iron-plate"))
  end)

  it("matches a substring anywhere in the target", function()
    assert.is_true(substring_match("plate", "iron-plate"))
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

  it("matches everything with an empty query", function()
    assert.is_true(substring_match("", "iron-plate"))
  end)

  it("does not match a query longer than the target", function()
    assert.is_false(substring_match("iron-plate-bar", "iron-plate"))
  end)
end)
