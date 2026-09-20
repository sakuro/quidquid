local CalculatorSource = require("lib.sources.calculator_source")

describe("CalculatorSource", function()
  describe(".format_result", function()
    it("trims a whole number to no decimal places", function()
      assert.are.equal("3", CalculatorSource.format_result(3))
    end)

    it("rounds to 4 decimal places", function()
      assert.are.equal("0.3333", CalculatorSource.format_result(1 / 3))
    end)

    it("trims trailing zeros but keeps significant decimals", function()
      assert.are.equal("2.5", CalculatorSource.format_result(2.5))
    end)

    it("keeps the sign of a negative result", function()
      assert.are.equal("-2.5", CalculatorSource.format_result(-2.5))
    end)

    it("formats a large integer without scientific notation", function()
      assert.are.equal("1500000", CalculatorSource.format_result(1500000))
    end)
  end)

  describe(".format_suffixed", function()
    it("matches format_result below 1000", function()
      assert.are.equal("999", CalculatorSource.format_suffixed(999))
      assert.are.equal("0.3333", CalculatorSource.format_suffixed(1 / 3))
      assert.are.equal("0", CalculatorSource.format_suffixed(0))
    end)

    it("shows one fixed decimal digit from 1000 up to 10000", function()
      assert.are.equal("1.0k", CalculatorSource.format_suffixed(1000))
      assert.are.equal("2.0k", CalculatorSource.format_suffixed(2000))
      assert.are.equal("9.9k", CalculatorSource.format_suffixed(9940))
    end)

    it("drops the decimal digit from 10000 up to 1000000", function()
      assert.are.equal("10k", CalculatorSource.format_suffixed(10000))
      assert.are.equal("23k", CalculatorSource.format_suffixed(23456))
      assert.are.equal("999k", CalculatorSource.format_suffixed(999400))
    end)

    it("moves to the next tier when rounding reaches 10 within the k tier", function()
      assert.are.equal("10k", CalculatorSource.format_suffixed(9999))
    end)

    it("moves to the next tier when rounding reaches 1000 within a tier", function()
      assert.are.equal("1.0M", CalculatorSource.format_suffixed(999999))
      assert.are.equal("1.0B", CalculatorSource.format_suffixed(999960000))
    end)

    it("uses M, B and T with one decimal digit", function()
      assert.are.equal("1.0M", CalculatorSource.format_suffixed(1e6))
      assert.are.equal("1.5M", CalculatorSource.format_suffixed(1.5e6))
      assert.are.equal("123.5M", CalculatorSource.format_suffixed(123456789))
      assert.are.equal("2.0B", CalculatorSource.format_suffixed(2e9))
      assert.are.equal("3.0T", CalculatorSource.format_suffixed(3e12))
    end)

    it("keeps counting in T beyond a thousand T", function()
      assert.are.equal("1000.0T", CalculatorSource.format_suffixed(1e15))
    end)

    it("keeps the sign of a negative value", function()
      assert.are.equal("-2.5k", CalculatorSource.format_suffixed(-2500))
      assert.are.equal("-23k", CalculatorSource.format_suffixed(-23456))
      assert.are.equal("-2.5", CalculatorSource.format_suffixed(-2.5))
    end)
  end)

  describe(".classify", function()
    it("returns the value on success", function()
      assert.are.equal(9, CalculatorSource.classify(true, 9))
    end)

    it("returns nil when pcall failed", function()
      assert.is_nil(CalculatorSource.classify(false, "parse error"))
    end)

    it("returns nil for a non-number result", function()
      assert.is_nil(CalculatorSource.classify(true, "not a number"))
    end)

    it("returns nil for NaN", function()
      assert.is_nil(CalculatorSource.classify(true, 0 / 0))
    end)

    it("returns nil for positive infinity", function()
      assert.is_nil(CalculatorSource.classify(true, 1 / 0))
    end)

    it("returns nil for negative infinity", function()
      assert.is_nil(CalculatorSource.classify(true, -1 / 0))
    end)
  end)

  describe(".build_candidate", function()
    it("marks the candidate as numeric so the palette right-aligns it", function()
      assert.is_true(CalculatorSource.build_candidate(9).numeric)
    end)

    it("formats the value as the candidate's label", function()
      assert.are.equal("0.3333", CalculatorSource.build_candidate(1 / 3).label)
    end)

    it("shows the suffixed value on the secondary line", function()
      assert.are.equal("23k", CalculatorSource.build_candidate(23456).search_internal_name)
    end)

    it("has a fixed type and id, since only one candidate ever exists", function()
      local candidate = CalculatorSource.build_candidate(9)

      assert.are.equal("calculation", candidate.type)
      assert.are.equal("result", candidate.id)
    end)
  end)
end)
