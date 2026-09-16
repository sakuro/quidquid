local PaletteLogic = require("lib.palette_logic")

describe("PaletteLogic", function()
  describe(".merge_candidates", function()
    it("returns an empty list when given no sources", function()
      local merged = PaletteLogic.merge_candidates({}, 30)

      assert.are.same({}, merged)
    end)

    it("returns all candidates from a single source in order", function()
      local merged = PaletteLogic.merge_candidates({ { "a", "b", "c" } }, 30)

      assert.are.same({ "a", "b", "c" }, merged)
    end)

    it("interleaves candidates round-robin across multiple sources", function()
      local merged = PaletteLogic.merge_candidates({ { "a1", "a2", "a3" }, { "b1", "b2", "b3" } }, 30)

      assert.are.same({ "a1", "b1", "a2", "b2", "a3", "b3" }, merged)
    end)

    it("truncates at the given limit", function()
      local merged = PaletteLogic.merge_candidates({ { "a1", "a2", "a3" }, { "b1", "b2", "b3" } }, 3)

      assert.are.same({ "a1", "b1", "a2" }, merged)
    end)

    it("continues with the remaining source once a shorter source is exhausted", function()
      local merged = PaletteLogic.merge_candidates({ { "a1" }, { "b1", "b2", "b3" } }, 30)

      assert.are.same({ "a1", "b1", "b2", "b3" }, merged)
    end)

    it("does not let an abundant source starve a later source within the limit", function()
      local merged = PaletteLogic.merge_candidates({ { "a1", "a2", "a3", "a4", "a5" }, { "b1" } }, 3)

      assert.are.same({ "a1", "b1", "a2" }, merged)
    end)
  end)

  describe(".move_index", function()
    it("starts at the first item when moving down", function()
      assert.are.equal(1, PaletteLogic.move_index(nil, 3, 1))
    end)

    it("starts at the last item when moving up", function()
      assert.are.equal(3, PaletteLogic.move_index(nil, 3, -1))
    end)

    it("wraps at both ends", function()
      assert.are.equal(3, PaletteLogic.move_index(1, 3, -1))
      assert.are.equal(1, PaletteLogic.move_index(3, 3, 1))
    end)

    it("returns nil for an empty list", function()
      assert.is_nil(PaletteLogic.move_index(nil, 0, 1))
    end)
  end)
end)
