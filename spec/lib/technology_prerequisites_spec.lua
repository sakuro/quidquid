local TechnologyPrerequisites = require("lib.technology_prerequisites")

local function technology(name, prerequisites, options)
  options = options or {}
  return {
    name = name,
    localised_name = { "technology-name." .. name },
    researched = options.researched or false,
    level = options.level or 0,
    saved_progress = options.saved_progress or 0,
    prototype = {
      max_level = options.max_level,
      research_trigger = options.research_trigger,
    },
    prerequisites = prerequisites or {},
  }
end

describe("TechnologyPrerequisites", function()
  describe(".is_multi_level", function()
    it("returns true for the infinite-technology level marker", function()
      local infinite = technology("mining-productivity", nil, { max_level = 4294967295 })

      assert.is_true(TechnologyPrerequisites.is_multi_level(infinite))
    end)

    it("returns true for the runtime's infinite marker", function()
      local infinite = technology("mining-productivity", nil, { max_level = "infinite" })

      assert.is_true(TechnologyPrerequisites.is_multi_level(infinite))
    end)

    it("returns false for a finite leveled-family technology, where max_level equals its own level", function()
      -- Confirmed via RCON against a real save: braking-force-4 (part of an
      -- upgrade = true numbered family) reports level = 4, max_level = 4 --
      -- unlike a genuine infinite technology, this isn't "level N of a
      -- repeatable prototype."
      local leveled = technology("braking-force-4", nil, { level = 4, max_level = 4 })

      assert.is_false(TechnologyPrerequisites.is_multi_level(leveled))
    end)

    it("returns false for a single-level technology", function()
      local single = technology("automation", nil, { max_level = 1 })

      assert.is_false(TechnologyPrerequisites.is_multi_level(single))
    end)
  end)

  describe(".technology_icon", function()
    it("returns a bare technology icon tag", function()
      assert.are.equal("[technology=automation]", TechnologyPrerequisites.technology_icon(technology("automation")))
    end)
  end)

  describe(".technology_name", function()
    it("appends the level with one space for infinite technologies", function()
      local infinite = technology("mining-productivity", nil, { level = 12 })
      infinite.prototype.max_level = 4294967295

      assert.are.same({
        "",
        { "technology-name.mining-productivity" },
        " ",
        12,
      }, TechnologyPrerequisites.technology_name(infinite))
    end)

    it("uses an explicitly provided level", function()
      local infinite = technology("mining-productivity", nil, { level = 12, max_level = "infinite" })

      assert.are.same({
        "",
        { "technology-name.mining-productivity" },
        " ",
        14,
      }, TechnologyPrerequisites.technology_name(infinite, 14))
    end)

    it("recognizes the infinite technology marker used by the runtime", function()
      local infinite = technology("mining-productivity", nil, { level = 12, max_level = "infinite" })

      assert.are.same({
        "",
        { "technology-name.mining-productivity" },
        " ",
        12,
      }, TechnologyPrerequisites.technology_name(infinite))
    end)

    it(
      "does not append a level for a finite leveled-family technology (already baked into its localised_name)",
      function()
        local leveled = technology("braking-force-4", nil, { level = 4, max_level = 4 })

        assert.are.same({
          "",
          { "technology-name.braking-force-4" },
        }, TechnologyPrerequisites.technology_name(leveled))
      end
    )
  end)

  describe(".technology_list_caption", function()
    it("lists prerequisite technologies as a single concatenated string", function()
      local prerequisites = {
        technology("automation"),
        technology("steel-processing"),
      }

      assert.are.same(
        { "", "[technology=automation], [technology=steel-processing]" },
        TechnologyPrerequisites.technology_list_caption(prerequisites)
      )
    end)

    it("truncates past MAX_LISTED_TECHNOLOGIES and names the correct remainder", function()
      local technologies = {}
      for i = 1, 8 do
        technologies[i] = technology("tech-" .. i)
      end

      local result = TechnologyPrerequisites.technology_list_caption(technologies)

      assert.are.same({
        "",
        "[technology=tech-1], [technology=tech-2], [technology=tech-3], "
          .. "[technology=tech-4], [technology=tech-5], [technology=tech-6], ",
        { "quidquid.action-research-queue-technology-list-more", 2 },
      }, result)
    end)
  end)

  describe(".collect_prerequisites", function()
    it("returns prerequisites in dependency order", function()
      local iron = technology("iron")
      local steel = technology("steel", { iron = iron })
      local automation = technology("automation", { steel = steel })

      local prerequisites, triggers = TechnologyPrerequisites.collect_prerequisites(automation, {})

      assert.are.same({ iron, steel }, prerequisites)
      assert.are.same({}, triggers)
    end)

    it("skips researched and queued prerequisites and finds nested trigger technologies", function()
      local researched = technology("researched", nil, { researched = true })
      local trigger = technology("trigger", nil, { research_trigger = { type = "craft-item" } })
      local queued = technology("queued")
      local target = technology("target", {
        researched = researched,
        trigger = trigger,
        queued = queued,
      })

      local prerequisites, triggers = TechnologyPrerequisites.collect_prerequisites(target, { queued = true })

      assert.are.same({}, prerequisites)
      assert.are.same({ trigger }, triggers)
    end)
  end)

  describe(".direct_prerequisites_researched", function()
    it("returns true when every direct prerequisite is researched", function()
      local iron = technology("iron", nil, { researched = true })
      local steel = technology("steel", nil, { researched = true })
      local target = technology("target", { iron = iron, steel = steel })

      assert.is_true(TechnologyPrerequisites.direct_prerequisites_researched(target))
    end)

    it("returns false when any direct prerequisite is unresearched", function()
      local iron = technology("iron", nil, { researched = true })
      local steel = technology("steel")
      local target = technology("target", { iron = iron, steel = steel })

      assert.is_false(TechnologyPrerequisites.direct_prerequisites_researched(target))
    end)

    it("returns true for a technology with no prerequisites", function()
      assert.is_true(TechnologyPrerequisites.direct_prerequisites_researched(technology("automation")))
    end)
  end)

  describe(".direct_prerequisites_queued", function()
    it("returns true when every unresearched direct prerequisite is queued", function()
      local iron = technology("iron", nil, { researched = true })
      local steel = technology("steel")
      local target = technology("target", { iron = iron, steel = steel })

      assert.is_true(TechnologyPrerequisites.direct_prerequisites_queued(target, { steel = true }))
    end)

    it("returns false when an unresearched direct prerequisite is not queued", function()
      local steel = technology("steel")
      local target = technology("target", { steel = steel })

      assert.is_false(TechnologyPrerequisites.direct_prerequisites_queued(target, {}))
    end)

    it("returns false for a trigger prerequisite, which can never be queued", function()
      local trigger = technology("trigger", nil, { research_trigger = { type = "craft-item" } })
      local target = technology("target", { trigger = trigger })

      assert.is_false(TechnologyPrerequisites.direct_prerequisites_queued(target, { trigger = true }))
    end)
  end)

  describe(".classify_state", function()
    it("returns researched for a researched technology", function()
      local target = technology("target", nil, { researched = true })

      assert.are.equal("researched", TechnologyPrerequisites.classify_state(target, {}))
    end)

    it("returns available when every direct prerequisite is researched", function()
      local iron = technology("iron", nil, { researched = true })
      local target = technology("target", { iron = iron })

      assert.are.equal("available", TechnologyPrerequisites.classify_state(target, {}))
    end)

    it("returns conditionally_available when an unresearched direct prerequisite is queued", function()
      local steel = technology("steel")
      local target = technology("target", { steel = steel })

      assert.are.equal("conditionally_available", TechnologyPrerequisites.classify_state(target, { steel = true }))
    end)

    it("returns not_available when an unresearched direct prerequisite is not queued", function()
      local steel = technology("steel")
      local target = technology("target", { steel = steel })

      assert.are.equal("not_available", TechnologyPrerequisites.classify_state(target, {}))
    end)
  end)
end)
