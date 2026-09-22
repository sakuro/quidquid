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

    it("returns true for a finite technology with more than one level", function()
      local finite = technology("worker-robots-speed", nil, { max_level = 6 })

      assert.is_true(TechnologyPrerequisites.is_multi_level(finite))
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

    it("appends the level for finite technologies with multiple levels", function()
      local finite = technology("worker-robots-speed", nil, { level = 3, max_level = 6 })

      assert.are.same({
        "",
        { "technology-name.worker-robots-speed" },
        " ",
        3,
      }, TechnologyPrerequisites.technology_name(finite))
    end)
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
end)
