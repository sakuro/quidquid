local LogisticsState = require("lib.logistics_state")

describe("LogisticsState", function()
  describe(".classify", function()
    it("returns no_character when the player has no character", function()
      assert.are.equal("no_character", LogisticsState.classify(false, nil))
    end)

    it("returns locked when the character has no requester logistic point", function()
      assert.are.equal("locked", LogisticsState.classify(true, nil))
    end)

    it("returns out_of_range when the requester point's network is nil", function()
      local requester_point = { logistic_network = nil }

      assert.are.equal("out_of_range", LogisticsState.classify(true, requester_point))
    end)

    it("returns out_of_range when the requester point's network is invalid", function()
      local requester_point = { logistic_network = { valid = false } }

      assert.are.equal("out_of_range", LogisticsState.classify(true, requester_point))
    end)

    it("returns connected when the requester point's network is valid", function()
      local requester_point = { logistic_network = { valid = true } }

      assert.are.equal("connected", LogisticsState.classify(true, requester_point))
    end)
  end)
end)
