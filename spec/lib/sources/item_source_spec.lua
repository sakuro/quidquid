local ItemSource = require("lib.sources.item_source")

describe("ItemSource", function()
  describe(".build_candidates", function()
    it("delegates to prototype_candidate with the item type and icon prefix", function()
      local items = {
        { name = "iron-plate", localised_name = { "item-name.iron-plate" }, hidden = false },
      }

      local candidates = ItemSource.build_candidates("iron", items, "en", {}, false)

      assert.are.equal(1, #candidates)
      assert.are.equal("item", candidates[1].type)
      assert.are.equal("iron-plate", candidates[1].id)
      assert.are.same({ "item-name.iron-plate" }, candidates[1].label)
      assert.are.equal("item/iron-plate", candidates[1].icon)
      assert.is_number(candidates[1].search_score)
      assert.are.equal("internal", candidates[1].search_field)
    end)
  end)
end)
