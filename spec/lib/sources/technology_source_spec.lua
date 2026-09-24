local TechnologyGraph = require("lib.technology_graph")
local TechnologySource = require("lib.sources.technology_source")
local TechnologyUpgradeChain = require("lib.technology_upgrade_chain")

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
        { "", "[color=red]", { "quidquid.technology-state-not-available" }, "[/color]" },
        TechnologySource.build_caption("not_available")
      )
    end)

    it("colors conditionally_available orange, same text as available", function()
      assert.are.same(
        { "", "[color=orange]", { "quidquid.technology-state-available" }, "[/color]" },
        TechnologySource.build_caption("conditionally_available")
      )
    end)

    it("colors available yellow", function()
      assert.are.same(
        { "", "[color=yellow]", { "quidquid.technology-state-available" }, "[/color]" },
        TechnologySource.build_caption("available")
      )
    end)

    it("colors researched green", function()
      assert.are.same(
        { "", "[color=green]", { "quidquid.technology-state-researched" }, "[/color]" },
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

  describe(".build_tooltip", function()
    it("returns nil when there is nothing to show", function()
      assert.is_nil(TechnologySource.build_tooltip("researched", {}, {}, 0, nil))
    end)

    it("shows the missing (transitive) prerequisites when present", function()
      local prerequisites = { { name = "steel-processing" } }

      local tooltip = TechnologySource.build_tooltip("available", prerequisites, {}, 0, nil)

      assert.are.same({
        "",
        { "quidquid.technology-missing-prerequisites", { "", "[technology=steel-processing]" } },
      }, tooltip)
    end)

    it("shows blocking trigger technologies alongside the prerequisites block", function()
      local prerequisites = { { name = "steel-processing" } }
      local triggers = { { name = "oil-processing" } }

      local tooltip = TechnologySource.build_tooltip("not_available", prerequisites, triggers, 0, nil)

      assert.are.same({
        "",
        { "quidquid.technology-missing-prerequisites", { "", "[technology=steel-processing]" } },
        "\n",
        { "quidquid.technology-blocked-by-triggers", { "", "[technology=oil-processing]" } },
      }, tooltip)
    end)

    it("shows progress when available and progress is greater than 0", function()
      local tooltip = TechnologySource.build_tooltip("available", {}, {}, 37, nil)

      assert.are.same({
        "",
        { "quidquid.technology-progress", 37 },
      }, tooltip)
    end)

    it("hides progress when available but progress is 0", function()
      assert.is_nil(TechnologySource.build_tooltip("available", {}, {}, 0, nil))
    end)

    it("hides progress when conditionally_available, even if progress is somehow greater than 0", function()
      assert.is_nil(TechnologySource.build_tooltip("conditionally_available", {}, {}, 37, nil))
    end)

    it("shows the research-complete-condition header and trigger content when given", function()
      local trigger_content = { "technology-trigger.craft-item", "[item=lab]" }

      local tooltip = TechnologySource.build_tooltip("available", {}, {}, 0, trigger_content)

      assert.are.same({
        "",
        { "", { "gui-technology-preview.unit-research-trigger-requirements" }, ": ", trigger_content },
      }, tooltip)
    end)

    it("combines every block when all apply", function()
      local prerequisites = { { name = "steel-processing" } }
      local triggers = { { name = "oil-processing" } }
      local trigger_content = { "technology-trigger.craft-item", "[item=lab]" }

      local tooltip = TechnologySource.build_tooltip("not_available", prerequisites, triggers, 0, trigger_content)

      assert.are.same({
        "",
        { "quidquid.technology-missing-prerequisites", { "", "[technology=steel-processing]" } },
        "\n",
        { "quidquid.technology-blocked-by-triggers", { "", "[technology=oil-processing]" } },
        "\n",
        { "", { "gui-technology-preview.unit-research-trigger-requirements" }, ": ", trigger_content },
      }, tooltip)
    end)
  end)

  describe(".build_annotation", function()
    it("combines the caption and tooltip", function()
      local annotation = TechnologySource.build_annotation("researched", {}, {}, 0, nil)

      assert.are.same(TechnologySource.build_caption("researched"), annotation.caption)
      assert.is_nil(annotation.tooltip)
    end)

    it("includes a non-nil tooltip when there is content for it", function()
      local prerequisites = { { name = "steel-processing" } }

      local annotation = TechnologySource.build_annotation("available", prerequisites, {}, 0, nil)

      assert.are.same(TechnologySource.build_tooltip("available", prerequisites, {}, 0, nil), annotation.tooltip)
    end)
  end)

  describe(".annotate", function()
    local function technology(name, options)
      options = options or {}
      return {
        name = name,
        researched = options.researched or false,
        saved_progress = options.saved_progress or 0,
        prototype = {
          research_trigger = options.research_trigger,
        },
        prerequisites = options.prerequisites or {},
      }
    end

    local function context(technologies, overrides)
      overrides = overrides or {}
      return {
        graph = TechnologyGraph.build(technologies),
        queued = overrides.queued or {},
        current_research_name = overrides.current_research_name,
        research_progress = overrides.research_progress or 0,
      }
    end

    it("returns nil for a candidate the force has no technology for", function()
      assert.is_nil(TechnologySource.annotate({ id = "nonexistent" }, context({})))
    end)

    it("captions a researched technology and leaves its tooltip empty", function()
      local ctx = context({ automation = technology("automation", { researched = true }) })

      local annotation = TechnologySource.annotate({ id = "automation" }, ctx)

      assert.are.same(
        { "", "[color=green]", { "quidquid.technology-state-researched" }, "[/color]" },
        annotation.caption
      )
      assert.is_nil(annotation.tooltip)
    end)

    it("reports saved progress for an available technology that is not being researched", function()
      local ctx = context({ automation = technology("automation", { saved_progress = 0.42 }) })

      local annotation = TechnologySource.annotate({ id = "automation" }, ctx)

      assert.are.same(
        { "", "[color=yellow]", { "quidquid.technology-state-available" }, "[/color]" },
        annotation.caption
      )
      assert.are.same({ "", { "quidquid.technology-progress", 42 } }, annotation.tooltip)
    end)

    it("prefers the force's live progress for the technology currently being researched", function()
      local ctx = context({ automation = technology("automation", { saved_progress = 0.42 }) }, {
        current_research_name = "automation",
        research_progress = 0.75,
      })

      local annotation = TechnologySource.annotate({ id = "automation" }, ctx)

      assert.are.same({ "", { "quidquid.technology-progress", 75 } }, annotation.tooltip)
    end)

    it("describes the research trigger of an unresearched trigger technology", function()
      local trigger = { type = "craft-item", item = { name = "electronic-circuit" }, count = 1 }
      local ctx = context({ ["electronics"] = technology("electronics", { research_trigger = trigger }) })

      local annotation = TechnologySource.annotate({ id = "electronics" }, ctx)

      assert.are.same({
        "",
        {
          "",
          { "gui-technology-preview.unit-research-trigger-requirements" },
          ": ",
          { "technology-trigger.craft-item", "[item=electronic-circuit]" },
        },
      }, annotation.tooltip)
    end)
  end)

  describe(".filter_visible", function()
    -- braking-force-1 .. -3, the shape the technology screen collapses.
    local function chain_links()
      return TechnologyUpgradeChain.build_links({
        { name = "braking-force-1", upgrade = true, prerequisites = {} },
        { name = "braking-force-2", upgrade = true, prerequisites = { ["braking-force-1"] = true } },
        { name = "braking-force-3", upgrade = true, prerequisites = { ["braking-force-2"] = true } },
      })
    end

    it("keeps a candidate the technology screen shows", function()
      local candidates = { { id = "braking-force-2" } }

      local visible = TechnologySource.filter_visible(candidates, chain_links(), { ["braking-force-1"] = true }, {})

      assert.are.equal(1, #visible)
      assert.are.equal("braking-force-2", visible[1].id)
    end)

    it("drops a candidate the technology screen hides", function()
      local candidates = { { id = "braking-force-3" } }

      local visible = TechnologySource.filter_visible(candidates, chain_links(), {}, {})

      assert.are.same({}, visible)
    end)

    it("keeps a candidate that belongs to no upgrade chain", function()
      local candidates = { { id = "automation" } }

      local visible = TechnologySource.filter_visible(candidates, chain_links(), {}, {})

      assert.are.equal(1, #visible)
    end)
  end)
end)
