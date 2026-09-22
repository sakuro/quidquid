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

  describe(".build_caption", function()
    it("colors not_available red", function()
      assert.are.same(
        { "", "[color=255,214,213]", { "quidquid.technology-state-not-available" }, "[/color]" },
        TechnologySource.build_caption("not_available")
      )
    end)

    it("colors conditionally_available orange, same text as available", function()
      assert.are.same(
        { "", "[color=255,234,206]", { "quidquid.technology-state-available" }, "[/color]" },
        TechnologySource.build_caption("conditionally_available")
      )
    end)

    it("colors available yellow", function()
      assert.are.same(
        { "", "[color=255,241,183]", { "quidquid.technology-state-available" }, "[/color]" },
        TechnologySource.build_caption("available")
      )
    end)

    it("colors researched green", function()
      assert.are.same(
        { "", "[color=165,255,171]", { "quidquid.technology-state-researched" }, "[/color]" },
        TechnologySource.build_caption("researched")
      )
    end)
  end)
end)
