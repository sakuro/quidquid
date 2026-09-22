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

  describe(".valid_value", function()
    it("returns the value on success", function()
      assert.are.equal(9, CalculatorSource.valid_value(true, 9))
    end)

    it("returns nil when pcall failed", function()
      assert.is_nil(CalculatorSource.valid_value(false, "parse error"))
    end)

    it("returns nil for a non-number result", function()
      assert.is_nil(CalculatorSource.valid_value(true, "not a number"))
    end)

    it("returns nil for NaN", function()
      assert.is_nil(CalculatorSource.valid_value(true, 0 / 0))
    end)

    it("returns nil for positive infinity", function()
      assert.is_nil(CalculatorSource.valid_value(true, 1 / 0))
    end)

    it("returns nil for negative infinity", function()
      assert.is_nil(CalculatorSource.valid_value(true, -1 / 0))
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
      assert.are.equal("23k", CalculatorSource.build_candidate(23456).secondary_text)
    end)

    it("has a fixed type and id, since only one candidate ever exists", function()
      local candidate = CalculatorSource.build_candidate(9)

      assert.are.equal("calculation", candidate.type)
      assert.are.equal("result", candidate.id)
    end)
  end)
end)
