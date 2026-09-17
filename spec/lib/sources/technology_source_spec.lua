local TechnologySource = require("lib.sources.technology_source")

describe("TechnologySource", function()
  describe(".build_candidates", function()
    it("delegates to prototype_candidate with the technology type and icon prefix", function()
      local technologies = {
        { name = "steam-power", localised_name = { "technology-name.steam-power" }, hidden = false },
      }

      local candidates = TechnologySource.build_candidates("steam", technologies, "en", {}, false)

      assert.are.equal(1, #candidates)
      assert.are.equal("technology", candidates[1].type)
      assert.are.equal("steam-power", candidates[1].id)
      assert.are.same({ "technology-name.steam-power" }, candidates[1].label)
      assert.are.equal("technology/steam-power", candidates[1].icon)
      assert.is_number(candidates[1].search_score)
    end)
  end)
end)
