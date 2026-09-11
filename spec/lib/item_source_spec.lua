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
    it("returns nothing for an empty item list", function()
      local candidates = ItemSource.build_candidates("iron", {}, "en", fake_translation_cache(), false)

      assert.are.same({}, candidates)
    end)

    it("matches an item by internal name", function()
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

    it("matches an item only by its cached translated name", function()
      -- The query "鉄" is not a substring of the internal name "iron-plate" itself, so this
      -- can only pass via the translated-name fallback, not the internal-name path.
      local items = {
        { name = "iron-plate", localised_name = {"item-name.iron-plate"}, hidden = false },
      }
      local translation_cache = fake_translation_cache({ en = { ["iron-plate"] = "鉄板" } })

      local candidates = ItemSource.build_candidates("鉄", items, "en", translation_cache, false)

      assert.are.equal(1, #candidates)
      assert.are.equal("iron-plate", candidates[1].id)
    end)

    it("excludes an item that matches neither name", function()
      local items = {
        { name = "iron-plate", localised_name = {"item-name.iron-plate"}, hidden = false },
      }

      local candidates = ItemSource.build_candidates("copper", items, "en", fake_translation_cache(), false)

      assert.are.same({}, candidates)
    end)

    it("does not match against a failed-translation sentinel", function()
      -- Same non-matching-on-internal-name query as the previous test, but this time the
      -- cached value is the `false` sentinel (translation attempted, failed) rather than a
      -- string — this must NOT be treated as a match.
      local items = {
        { name = "iron-plate", localised_name = {"item-name.iron-plate"}, hidden = false },
      }
      local translation_cache = fake_translation_cache({ en = { ["iron-plate"] = false } })

      local candidates = ItemSource.build_candidates("鉄", items, "en", translation_cache, false)

      assert.are.same({}, candidates)
    end)

    it("excludes a hidden item when include_hidden is false", function()
      local items = {
        { name = "debug-marker", localised_name = {"item-name.debug-marker"}, hidden = true },
      }

      local candidates = ItemSource.build_candidates("debug", items, "en", fake_translation_cache(), false)

      assert.are.same({}, candidates)
    end)

    it("includes a hidden item when include_hidden is true", function()
      local items = {
        { name = "debug-marker", localised_name = {"item-name.debug-marker"}, hidden = true },
      }

      local candidates = ItemSource.build_candidates("debug", items, "en", fake_translation_cache(), true)

      assert.are.equal(1, #candidates)
    end)

    it("filters a mixed list down to only the matching, visible items", function()
      local items = {
        { name = "iron-plate", localised_name = {"item-name.iron-plate"}, hidden = false },
        { name = "copper-plate", localised_name = {"item-name.copper-plate"}, hidden = false },
        { name = "iron-ore", localised_name = {"item-name.iron-ore"}, hidden = false },
        { name = "secret-plate", localised_name = {"item-name.secret-plate"}, hidden = true },
      }

      local candidates = ItemSource.build_candidates("plate", items, "en", fake_translation_cache(), false)

      assert.are.equal(2, #candidates)
      assert.are.equal("iron-plate", candidates[1].id)
      assert.are.equal("copper-plate", candidates[2].id)
    end)
  end)
end)
