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

  describe(".build_trigger_content", function()
    it("describes a craft-item trigger with count 1", function()
      local research_trigger = { type = "craft-item", item = { name = "lab" }, count = 1 }

      assert.are.same(
        { "technology-trigger.craft-item", "[item=lab]" },
        TechnologySource.build_trigger_content(research_trigger)
      )
    end)

    it("describes a craft-item trigger with count > 1, count before the item", function()
      local research_trigger = { type = "craft-item", item = { name = "iron-plate" }, count = 50 }

      assert.are.same(
        { "technology-trigger.craft-items", 50, "[item=iron-plate]" },
        TechnologySource.build_trigger_content(research_trigger)
      )
    end)

    it("describes a mine-entity trigger with one entity", function()
      local research_trigger = { type = "mine-entity", entities = { "crude-oil" } }

      assert.are.same(
        { "technology-trigger.mine-entity", "[entity=crude-oil]" },
        TechnologySource.build_trigger_content(research_trigger)
      )
    end)

    it("describes a mine-entity trigger with several entities as a newline-joined list", function()
      local research_trigger = { type = "mine-entity", entities = { "big-volcanic-rock", "huge-volcanic-rock" } }

      assert.are.same(
        { "technology-trigger.mine-entities", { "", "[entity=big-volcanic-rock]\n[entity=huge-volcanic-rock]" } },
        TechnologySource.build_trigger_content(research_trigger)
      )
    end)

    it("describes a build-entity trigger", function()
      local research_trigger = { type = "build-entity", entity = { name = "asteroid-collector" } }

      assert.are.same(
        { "technology-trigger.build-entity", "[entity=asteroid-collector]" },
        TechnologySource.build_trigger_content(research_trigger)
      )
    end)

    it("describes a capture-spawner trigger with a specific entity", function()
      local research_trigger = { type = "capture-spawner", entity = { name = "biter-spawner" } }

      assert.are.same(
        { "technology-trigger.capture-spawner", "[entity=biter-spawner]" },
        TechnologySource.build_trigger_content(research_trigger)
      )
    end)

    it("describes a capture-spawner trigger with no specific entity", function()
      local research_trigger = { type = "capture-spawner" }

      assert.are.same(
        { "technology-trigger.capture-any-spawner" },
        TechnologySource.build_trigger_content(research_trigger)
      )
    end)

    it("describes a create-space-platform trigger", function()
      local research_trigger = { type = "create-space-platform" }

      assert.are.same(
        { "technology-trigger.create-space-platform" },
        TechnologySource.build_trigger_content(research_trigger)
      )
    end)

    it("describes a send-item-to-orbit trigger", function()
      local research_trigger = { type = "send-item-to-orbit", item = { name = "space-platform-starter-pack" } }

      assert.are.same(
        { "technology-trigger.send-item-to-orbit", "[item=space-platform-starter-pack]" },
        TechnologySource.build_trigger_content(research_trigger)
      )
    end)

    it("uses the trigger's own trigger_description for a scripted trigger", function()
      local research_trigger = { type = "scripted", trigger_description = { "mod.some-scripted-trigger" } }

      assert.are.same({ "mod.some-scripted-trigger" }, TechnologySource.build_trigger_content(research_trigger))
    end)

    it("returns nil for craft-fluid, deferred", function()
      local research_trigger = { type = "craft-fluid", fluid = "water", amount = 100 }

      assert.is_nil(TechnologySource.build_trigger_content(research_trigger))
    end)
  end)
end)
