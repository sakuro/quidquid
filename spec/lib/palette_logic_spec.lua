local PaletteLogic = require("lib.palette_logic")

describe("PaletteLogic", function()
  describe(".merge_candidates", function()
    it("returns an empty list when given no sources", function()
      local merged = PaletteLogic.merge_candidates({}, 30)

      assert.are.same({}, merged)
    end)

    it("truncates scored candidates at the given limit", function()
      local merged = PaletteLogic.merge_candidates({
        {
          { candidate = { id = "a1", search_score = 3 }, source_label = "A" },
          { candidate = { id = "a2", search_score = 1 }, source_label = "A" },
        },
        {
          { candidate = { id = "b1", search_score = 2 }, source_label = "B" },
          { candidate = { id = "b2", search_score = 0 }, source_label = "B" },
        },
      }, 3)

      assert.are.same({ "a1", "b1", "a2" }, {
        merged[1].candidate.id,
        merged[2].candidate.id,
        merged[3].candidate.id,
      })
    end)

    it("sorts scored candidates globally while keeping stable ties", function()
      local merged = PaletteLogic.merge_candidates({
        {
          { candidate = { id = "a1", search_score = 2 }, source_label = "A" },
          { candidate = { id = "a2", search_score = 1 }, source_label = "A" },
        },
        {
          { candidate = { id = "b1", search_score = 3 }, source_label = "B" },
          { candidate = { id = "b2", search_score = 1 }, source_label = "B" },
        },
      }, 30)

      assert.are.same({ "b1", "a1", "a2", "b2" }, {
        merged[1].candidate.id,
        merged[2].candidate.id,
        merged[3].candidate.id,
        merged[4].candidate.id,
      })
    end)
  end)

  describe(".apply_decoration", function()
    it("merges presentational fields from the decoration into the candidate", function()
      local candidate = { label = "Iron ore", icon = "entity/iron-ore" }

      PaletteLogic.apply_decoration(candidate, { label = "Iron ore (occupied)", search_display_name = "Iron ore" })

      assert.are.equal("Iron ore (occupied)", candidate.label)
      assert.are.equal("Iron ore", candidate.search_display_name)
    end)

    it("ignores type, id and search_score even when the decoration sets them", function()
      local candidate = { type = "resource", id = "cluster-1", search_score = 5, label = "Iron ore" }

      PaletteLogic.apply_decoration(
        candidate,
        { type = "item", id = "cluster-2", search_score = 99, label = "Iron ore (occupied)" }
      )

      assert.are.equal("resource", candidate.type)
      assert.are.equal("cluster-1", candidate.id)
      assert.are.equal(5, candidate.search_score)
      assert.are.equal("Iron ore (occupied)", candidate.label)
    end)

    it("leaves the candidate untouched when the decoration is nil", function()
      local candidate = { label = "Iron ore", icon = "entity/iron-ore" }

      PaletteLogic.apply_decoration(candidate, nil)

      assert.are.same({ label = "Iron ore", icon = "entity/iron-ore" }, candidate)
    end)

    it("preserves fields the decoration does not mention", function()
      local candidate = { label = "Iron ore", icon = "entity/iron-ore", secondary_text = "Nauvis (10, 20)" }

      PaletteLogic.apply_decoration(candidate, { label = "Iron ore (occupied)" })

      assert.are.equal("entity/iron-ore", candidate.icon)
      assert.are.equal("Nauvis (10, 20)", candidate.secondary_text)
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
