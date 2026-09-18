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
end)
