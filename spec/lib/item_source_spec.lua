local ItemSource = require("lib.item_source")

local function fake_translation_cache(entries)
  entries = entries or {}
  return {
    get = function(_, locale, internal_name)
      local by_locale = entries[locale]
      if by_locale == nil then
        return nil
      end
      return by_locale[internal_name]
    end,
  }
end

describe("ItemSource", function()
  describe(".build_candidates", function()
    it("delegates to prototype_candidate with the item type and icon prefix", function()
      local items = {
        { name = "iron-plate", localised_name = {"item-name.iron-plate"}, hidden = false },
      }

      local candidates = ItemSource.build_candidates("iron", items, "en", fake_translation_cache(), false)

      assert.are.equal(1, #candidates)
      assert.are.same(
        { type = "item", id = "iron-plate", label = {"item-name.iron-plate"}, icon = "item/iron-plate" },
        candidates[1]
      )
    end)
  end)
end)
