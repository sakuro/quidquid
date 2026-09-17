local FluidSource = require("lib.sources.fluid_source")

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

describe("FluidSource", function()
  describe(".build_candidates", function()
    it("builds fluid candidates with fluid icons", function()
      local fluids = {
        { name = "water", localised_name = { "fluid-name.water" }, hidden = false },
      }

      local candidates = FluidSource.build_candidates("water", fluids, "en", fake_translation_cache(), false)

      assert.are.equal(1, #candidates)
      assert.are.equal("fluid", candidates[1].type)
      assert.are.equal("water", candidates[1].id)
      assert.are.same({ "fluid-name.water" }, candidates[1].label)
      assert.are.equal("fluid/water", candidates[1].icon)
      assert.is_number(candidates[1].search_score)
    end)
  end)
end)
