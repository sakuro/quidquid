local ItemCounts = require("lib.item_counts")

describe("ItemCounts", function()
  describe(".merge", function()
    it("indexes a single contents list by name and quality", function()
      local index = ItemCounts.merge({ { name = "iron-plate", quality = "normal", count = 40 } })

      assert.are.equal(40, index["iron-plate"]["normal"])
    end)

    it("sums matching name/quality entries across several contents lists", function()
      local main_inventory = { { name = "iron-plate", quality = "normal", count = 40 } }
      local cursor_stack = { { name = "iron-plate", quality = "normal", count = 12 } }

      local index = ItemCounts.merge(main_inventory, cursor_stack)

      assert.are.equal(52, index["iron-plate"]["normal"])
    end)
  end)

  describe(".total", function()
    it("sums an item's count across every quality", function()
      local index = ItemCounts.merge({
        { name = "iron-plate", quality = "normal", count = 40 },
        { name = "iron-plate", quality = "legendary", count = 5 },
      })

      assert.are.equal(45, ItemCounts.total(index, "iron-plate"))
    end)

    it("returns 0 for an item with no entries", function()
      local index = ItemCounts.merge({})

      assert.are.equal(0, ItemCounts.total(index, "iron-plate"))
    end)
  end)

  describe(".breakdown", function()
    it("lists each quality present, sorted by quality name", function()
      local index = ItemCounts.merge({
        { name = "iron-plate", quality = "legendary", count = 5 },
        { name = "iron-plate", quality = "normal", count = 40 },
      })

      assert.are.same({
        { quality = "legendary", count = 5 },
        { quality = "normal", count = 40 },
      }, ItemCounts.breakdown(index, "iron-plate"))
    end)

    it("returns an empty list for an item with no entries", function()
      local index = ItemCounts.merge({})

      assert.are.same({}, ItemCounts.breakdown(index, "iron-plate"))
    end)

    it("sorts by quality_order (e.g. tier level) instead of quality name when given", function()
      local index = ItemCounts.merge({
        { name = "iron-plate", quality = "legendary", count = 5 },
        { name = "iron-plate", quality = "normal", count = 40 },
        { name = "iron-plate", quality = "rare", count = 8 },
      })
      local quality_order = { normal = 0, uncommon = 1, rare = 2, epic = 3, legendary = 5 }

      assert.are.same({
        { quality = "normal", count = 40 },
        { quality = "rare", count = 8 },
        { quality = "legendary", count = 5 },
      }, ItemCounts.breakdown(index, "iron-plate", quality_order))
    end)
  end)
end)
