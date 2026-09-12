-- spec/lib/palette_logic_spec.lua
local PaletteLogic = require("lib.palette_logic")

describe("PaletteLogic", function()
  describe(".merge_candidates", function()
    it("returns nothing for an empty results list", function()
      assert.are.same({}, PaletteLogic.merge_candidates({}, 10))
    end)

    it("returns all candidates from a single source under the limit", function()
      local results = { { "a", "b", "c" } }

      assert.are.same({ "a", "b", "c" }, PaletteLogic.merge_candidates(results, 10))
    end)

    it("truncates a single source at the limit", function()
      local results = { { "a", "b", "c", "d", "e" } }

      assert.are.same({ "a", "b", "c" }, PaletteLogic.merge_candidates(results, 3))
    end)

    it("interleaves multiple sources round-robin, not source-by-source", function()
      local results = { { "a1", "a2", "a3" }, { "b1", "b2", "b3" } }

      assert.are.same({ "a1", "b1", "a2", "b2", "a3", "b3" }, PaletteLogic.merge_candidates(results, 10))
    end)

    it("does not let one abundant source starve out a smaller one", function()
      local results = { { "a1", "a2", "a3", "a4", "a5" }, { "b1" } }

      assert.are.same({ "a1", "b1", "a2", "a3", "a4" }, PaletteLogic.merge_candidates(results, 5))
    end)

    it("keeps interleaving from remaining sources once one is exhausted", function()
      local results = { { "a1" }, { "b1", "b2", "b3" } }

      assert.are.same({ "a1", "b1", "b2", "b3" }, PaletteLogic.merge_candidates(results, 10))
    end)
  end)

  describe(".resolve_confirm_key", function()
    it("returns confirm when neither shift nor control is held", function()
      assert.are.equal("confirm", PaletteLogic.resolve_confirm_key(false, false))
    end)

    it("returns confirm-shift when only shift is held", function()
      assert.are.equal("confirm-shift", PaletteLogic.resolve_confirm_key(true, false))
    end)

    it("returns confirm-ctrl when only control is held", function()
      assert.are.equal("confirm-ctrl", PaletteLogic.resolve_confirm_key(false, true))
    end)

    it("prefers confirm-ctrl when both shift and control are held", function()
      assert.are.equal("confirm-ctrl", PaletteLogic.resolve_confirm_key(true, true))
    end)
  end)

  describe(".badge_number", function()
    it("returns the index itself for positions 1 through 9", function()
      for i = 1, 9 do
        assert.are.equal(i, PaletteLogic.badge_number(i))
      end
    end)

    it("returns 0 for position 10", function()
      assert.are.equal(0, PaletteLogic.badge_number(10))
    end)

    it("returns nil past position 10", function()
      assert.is_nil(PaletteLogic.badge_number(11))
      assert.is_nil(PaletteLogic.badge_number(30))
    end)
  end)
end)
