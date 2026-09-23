local normalization = require("lib.search_normalization")

describe("search_normalization", function()
  local function normalized(value, locale)
    return normalization.normalize(value, "display", locale)
  end

  it("folds case and accents without changing punctuation", function()
    assert.are.equal("cafe-au-lait", normalized("Café-au-lait"))
  end)

  it("supports full case-fold expansions", function()
    assert.are.equal("strasse", normalized("Straße"))
    assert.are.equal("office", normalized("Oﬃce"))
  end)

  it("canonicalizes hiragana and halfwidth kana to katakana", function()
    assert.are.equal("ベルト", normalized("べると"))
    assert.are.equal("ガス", normalized("ｶﾞｽ"))
  end)

  it("preserves Japanese dakuten as a meaningful distinction", function()
    assert.are_not.equal(normalized("か"), normalized("が"))
    assert.are.equal("カ", normalized("か"))
    assert.are.equal("カ", normalized("カ"))
  end)

  it("uses the Turkish I exception only for the Turkish locale", function()
    assert.are.equal("i", normalized("I", "en"))
    assert.are.equal("ı", normalized("I", "tr"))
    assert.are.equal("i", normalized("İ", "tr"))
  end)

  it("folds Greek sigma variants without transliterating Greek", function()
    assert.are.equal("σ", normalized("Σ"))
    assert.are.equal("σ", normalized("ς"))
    assert.are_not.equal("s", normalized("σ"))
  end)

  it("removes Arabic and Hebrew reading marks and Tatweel", function()
    assert.are.equal("السلام", normalized("السَّلَامـ"))
    assert.are.equal("שלום", normalized("שָׁלוֹם"))
  end)

  -- The arguments below are fullwidth (U+FF21, U+FF29...), not ASCII; they look
  -- almost identical in a proportional font, so check before "correcting" them.
  it("case-folds fullwidth letters", function()
    assert.are.equal("a", normalized("Ａ"))
    assert.are.equal("iron", normalized("Ｉｒｏｎ"))
  end)

  it("applies canonical decomposition past the first level", function()
    assert.are.equal("a", normalized("ǟ"))
    assert.are.equal("u", normalized("ǖ"))
    assert.are.equal("e", normalized("ḕ"))
  end)

  it("returns a normalized-codepoint to original-byte-range map", function()
    local value, position_map = normalized("Straße")
    assert.are.equal("strasse", value)
    assert.are.same({ start_byte = 5, end_byte = 6 }, position_map[5])
    assert.are.same({ start_byte = 5, end_byte = 6 }, position_map[6])
  end)

  it("returns the raw value for malformed UTF-8", function()
    local value, position_map = normalized("\255")
    assert.are.equal("\255", value)
    assert.is_nil(position_map)
  end)
end)
