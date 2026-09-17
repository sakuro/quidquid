local search_key_cache = require("lib.search_key_cache")
local normalization = require("lib.search_normalization")

describe("search_key_cache", function()
  before_each(function()
    search_key_cache.clear()
  end)

  local function spy_on_normalize()
    local calls = 0
    local original = normalization.normalize
    normalization.normalize = function(...)
      calls = calls + 1
      return original(...)
    end
    return function()
      normalization.normalize = original
      return calls
    end
  end

  it("returns the same value and position map normalization.normalize would produce", function()
    local expected_value, expected_position_map = normalization.normalize("Iron Plate", "display", "en")

    local value, position_map = search_key_cache.get("prototype", "iron-plate", "display", "en", "Iron Plate")

    assert.are.equal(expected_value, value)
    assert.are.same(expected_position_map, position_map)
  end)

  it("passes a non-string raw value through without normalizing", function()
    local restore = spy_on_normalize()
    local value, position_map = search_key_cache.get("prototype", "iron-plate", "display", "en", nil)
    local calls = restore()

    assert.are.equal(0, calls)
    assert.is_nil(value)
    assert.are.same({}, position_map)
  end)

  it("reuses the cached value on a second call with identical inputs", function()
    local restore = spy_on_normalize()
    search_key_cache.get("prototype", "iron-plate", "display", "en", "Iron Plate")
    search_key_cache.get("prototype", "iron-plate", "display", "en", "Iron Plate")
    local calls = restore()

    assert.are.equal(1, calls)
  end)

  it("recomputes when the raw value changes for the same key", function()
    local restore = spy_on_normalize()
    search_key_cache.get("prototype", "iron-plate", "display", "en", "Iron Plate")
    search_key_cache.get("prototype", "iron-plate", "display", "en", "Iron Plate Renamed")
    local calls = restore()

    assert.are.equal(2, calls)
  end)

  it("recomputes when the locale changes for the same key", function()
    local restore = spy_on_normalize()
    search_key_cache.get("prototype", "iron-plate", "display", "en", "Iron Plate")
    search_key_cache.get("prototype", "iron-plate", "display", "fr", "Iron Plate")
    local calls = restore()

    assert.are.equal(2, calls)
  end)

  it("recomputes when normalization.rule_version changes", function()
    local restore = spy_on_normalize()
    search_key_cache.get("prototype", "iron-plate", "display", "en", "Iron Plate")

    local original_rule_version = normalization.rule_version
    normalization.rule_version = original_rule_version .. "-changed"
    search_key_cache.get("prototype", "iron-plate", "display", "en", "Iron Plate")
    normalization.rule_version = original_rule_version

    local calls = restore()
    assert.are.equal(2, calls)
  end)

  it("keeps namespaces isolated even for the same candidate id/field/locale", function()
    local restore = spy_on_normalize()
    search_key_cache.get("prototype", "iron-plate", "display", "en", "Iron Plate")
    search_key_cache.get("surface", "iron-plate", "display", "en", "Iron Plate")
    local calls = restore()

    assert.are.equal(2, calls)
  end)

  it("clear() forces every subsequent lookup to recompute", function()
    local restore = spy_on_normalize()
    search_key_cache.get("prototype", "iron-plate", "display", "en", "Iron Plate")
    search_key_cache.clear()
    search_key_cache.get("prototype", "iron-plate", "display", "en", "Iron Plate")
    local calls = restore()

    assert.are.equal(2, calls)
  end)
end)
