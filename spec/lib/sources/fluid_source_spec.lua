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

      assert.are.same({
        {
          type = "fluid",
          id = "water",
          label = { "fluid-name.water" },
          icon = "fluid/water",
        },
      }, candidates)
    end)
  end)
end)
