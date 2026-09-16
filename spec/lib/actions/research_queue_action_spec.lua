local ResearchQueueAction = require("lib.actions.research_queue_action")

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

describe("ResearchQueueAction", function()
  describe(".technology_list", function()
    it("lists prerequisite technologies as icons only", function()
      local prerequisites = {
        technology("automation"),
        technology("steel-processing"),
      }

      assert.are.same(
        { "", "[technology=automation]", ", ", "[technology=steel-processing]" },
        ResearchQueueAction.technology_list(prerequisites)
      )
    end)
  end)

  describe(".technology_caption", function()
    it("appends the level with one space for infinite technologies", function()
      local infinite = technology("mining-productivity", nil, { level = 12 })
      infinite.prototype.max_level = 4294967295

      assert.are.same({
        "",
        "[technology=mining-productivity] ",
        { "technology-name.mining-productivity" },
        " ",
        12,
      }, ResearchQueueAction.technology_caption(infinite))
    end)

    it("recognizes the infinite technology marker used by the runtime", function()
      local infinite = technology("mining-productivity", nil, { level = 12, max_level = "infinite" })

      assert.are.same({
        "",
        "[technology=mining-productivity] ",
        { "technology-name.mining-productivity" },
        " ",
        12,
      }, ResearchQueueAction.technology_caption(infinite))
    end)

    it("appends the level for finite technologies with multiple levels", function()
      local finite = technology("worker-robots-speed", nil, { level = 3, max_level = 6 })

      assert.are.same({
        "",
        "[technology=worker-robots-speed] ",
        { "technology-name.worker-robots-speed" },
        " ",
        3,
      }, ResearchQueueAction.technology_caption(finite))
    end)
  end)

  describe(".collect_prerequisites", function()
    it("returns prerequisites in dependency order", function()
      local iron = technology("iron")
      local steel = technology("steel", { iron = iron })
      local automation = technology("automation", { steel = steel })

      local prerequisites, triggers = ResearchQueueAction.collect_prerequisites(automation, {})

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

      local prerequisites, triggers = ResearchQueueAction.collect_prerequisites(target, { queued = true })

      assert.are.same({}, prerequisites)
      assert.are.same({ trigger }, triggers)
    end)
  end)

  describe(".progress_for", function()
    it("uses force progress for the current research and saved progress otherwise", function()
      local force = { research_progress = 0.234 }
      local queued = technology("queued", nil, { saved_progress = 0.678 })

      assert.are.equal(23, ResearchQueueAction.progress_for(force, queued, 1))
      assert.are.equal(68, ResearchQueueAction.progress_for(force, queued, 2))
    end)
  end)

  describe(".queue_index", function()
    it("does not treat an infinite technology already in the queue as a duplicate", function()
      local infinite = technology("mining-productivity", nil, { max_level = 4294967295 })

      assert.is_nil(ResearchQueueAction.queue_index({ infinite }, infinite))
    end)

    it("finds a finite technology already in the queue", function()
      local finite = technology("automation")

      assert.are.equal(2, ResearchQueueAction.queue_index({ technology("steel"), finite }, finite))
    end)

    it("does not treat a finite multi-level technology already in the queue as a duplicate", function()
      local finite = technology("worker-robots-speed", nil, { max_level = 6 })

      assert.is_nil(ResearchQueueAction.queue_index({ finite }, finite))
    end)
  end)
end)
