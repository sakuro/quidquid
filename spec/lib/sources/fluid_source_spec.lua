local FluidSource = require("lib.sources.fluid_source")

describe("FluidSource", function()
  describe(".build_candidates", function()
    it("builds fluid candidates with fluid icons", function()
      local fluids = {
        { name = "water", localised_name = { "fluid-name.water" }, hidden = false },
      }

      local candidates = FluidSource.build_candidates("water", fluids, "en", {}, false)

      assert.are.equal(1, #candidates)
      assert.are.equal("fluid", candidates[1].type)
      assert.are.equal("water", candidates[1].id)
      assert.are.same({ "fluid-name.water" }, candidates[1].label)
      assert.are.equal("fluid/water", candidates[1].icon)
      assert.is_number(candidates[1].search_score)
    end)
  end)
end)
