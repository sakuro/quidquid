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

local function force(technologies, research_queue, research_progress)
  return {
    technologies = technologies,
    research_queue = research_queue or {},
    research_progress = research_progress or 0,
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

  describe(".technology_icon", function()
    it("returns a bare technology icon tag", function()
      assert.are.equal("[technology=automation]", ResearchQueueAction.technology_icon(technology("automation")))
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
      }, ResearchQueueAction.technology_name(infinite))
    end)

    it("uses an explicitly provided level", function()
      local infinite = technology("mining-productivity", nil, { level = 12, max_level = "infinite" })

      assert.are.same({
        "",
        { "technology-name.mining-productivity" },
        " ",
        14,
      }, ResearchQueueAction.technology_name(infinite, 14))
    end)

    it("recognizes the infinite technology marker used by the runtime", function()
      local infinite = technology("mining-productivity", nil, { level = 12, max_level = "infinite" })

      assert.are.same({
        "",
        { "technology-name.mining-productivity" },
        " ",
        12,
      }, ResearchQueueAction.technology_name(infinite))
    end)

    it("appends the level for finite technologies with multiple levels", function()
      local finite = technology("worker-robots-speed", nil, { level = 3, max_level = 6 })

      assert.are.same({
        "",
        { "technology-name.worker-robots-speed" },
        " ",
        3,
      }, ResearchQueueAction.technology_name(finite))
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

  describe(".queued_level", function()
    it("increments the displayed level for each queued level", function()
      local infinite = technology("mining-productivity", nil, { level = 12, max_level = "infinite" })

      assert.are.equal(14, ResearchQueueAction.queued_level({ infinite, infinite }, infinite))
    end)

    it("does not change the level for non-level-based technologies", function()
      local finite = technology("automation", nil, { level = 1, max_level = 1 })

      assert.are.equal(1, ResearchQueueAction.queued_level({ finite }, finite))
    end)
  end)

  describe(".resolve_enqueue", function()
    it("returns nil for a candidate with no matching force technology", function()
      assert.is_nil(ResearchQueueAction.resolve_enqueue(force({}), { id = "automation" }))
    end)

    it("names the current research as such and reports force progress", function()
      local automation = technology("automation")
      local f = force({ automation = automation }, { automation }, 0.5)

      local result_technology, key, args, new_queue = ResearchQueueAction.resolve_enqueue(f, { id = "automation" })

      assert.are.equal(automation, result_technology)
      assert.are.equal("quidquid.action-research-queue-current", key)
      assert.are.same({ 50 }, args)
      assert.is_nil(new_queue)
    end)

    it("names an already-queued technology and reports its saved progress", function()
      local automation = technology("automation", nil, { saved_progress = 0.25 })
      local steel = technology("steel")
      local f = force({ automation = automation }, { steel, automation })

      local result_technology, key, args, new_queue = ResearchQueueAction.resolve_enqueue(f, { id = "automation" })

      assert.are.equal(automation, result_technology)
      assert.are.equal("quidquid.action-research-queue-already-queued", key)
      assert.are.same({ 25 }, args)
      assert.is_nil(new_queue)
    end)

    it("reports an already-researched technology", function()
      local automation = technology("automation", nil, { researched = true })
      local f = force({ automation = automation })

      local result_technology, key, args, new_queue = ResearchQueueAction.resolve_enqueue(f, { id = "automation" })

      assert.are.equal(automation, result_technology)
      assert.are.equal("quidquid.action-research-queue-already-researched", key)
      assert.are.same({}, args)
      assert.is_nil(new_queue)
    end)

    it("reports a full queue", function()
      local automation = technology("automation")
      local full_queue = {}
      for i = 1, 7 do
        full_queue[i] = technology("filler-" .. i)
      end
      local f = force({ automation = automation }, full_queue)

      local result_technology, key, args, new_queue = ResearchQueueAction.resolve_enqueue(f, { id = "automation" })

      assert.are.equal(automation, result_technology)
      assert.are.equal("quidquid.action-research-queue-full", key)
      assert.are.same({}, args)
      assert.is_nil(new_queue)
    end)

    it("reports a trigger technology as unqueueable", function()
      local trigger = technology("trigger", nil, { research_trigger = { type = "craft-item" } })
      local f = force({ trigger = trigger })

      local result_technology, key, args, new_queue = ResearchQueueAction.resolve_enqueue(f, { id = "trigger" })

      assert.are.equal(trigger, result_technology)
      assert.are.equal("quidquid.action-research-queue-trigger", key)
      assert.are.same({}, args)
      assert.is_nil(new_queue)
    end)

    it("reports trigger prerequisites as unqueueable", function()
      local trigger = technology("trigger", nil, { research_trigger = { type = "craft-item" } })
      local target = technology("target", { trigger = trigger })
      local f = force({ target = target })

      local result_technology, key, args, new_queue = ResearchQueueAction.resolve_enqueue(f, { id = "target" })

      assert.are.equal(target, result_technology)
      assert.are.equal("quidquid.action-research-queue-trigger-prerequisite", key)
      assert.are.same({ "", "[technology=trigger]" }, args[1])
      assert.is_nil(new_queue)
    end)

    it("reports not enough queue slots for prerequisites", function()
      local iron = technology("iron")
      local steel = technology("steel", { iron = iron })
      local target = technology("target", { steel = steel })
      local full_queue = {}
      for i = 1, 6 do
        full_queue[i] = technology("filler-" .. i)
      end
      local f = force({ target = target }, full_queue)

      local result_technology, key, args, new_queue = ResearchQueueAction.resolve_enqueue(f, { id = "target" })

      assert.are.equal(target, result_technology)
      assert.are.equal("quidquid.action-research-queue-prerequisite-slots", key)
      assert.are.same({ "", "[technology=iron]", ", ", "[technology=steel]" }, args[1])
      assert.is_nil(new_queue)
    end)

    it("enqueues a technology with no prerequisites", function()
      local automation = technology("automation")
      local steel = technology("steel")
      local f = force({ automation = automation }, { steel })

      local result_technology, key, args, new_queue = ResearchQueueAction.resolve_enqueue(f, { id = "automation" })

      assert.are.equal(automation, result_technology)
      assert.are.equal("quidquid.action-research-queue-added", key)
      assert.are.same({}, args)
      assert.are.same({ "steel", "automation" }, new_queue)
    end)

    it("enqueues a technology together with its unresearched, unqueued prerequisites", function()
      local iron = technology("iron")
      local steel = technology("steel", { iron = iron })
      local target = technology("target", { steel = steel })
      local f = force({ target = target })

      local result_technology, key, args, new_queue = ResearchQueueAction.resolve_enqueue(f, { id = "target" })

      assert.are.equal(target, result_technology)
      assert.are.equal("quidquid.action-research-queue-added-with-prerequisites", key)
      assert.are.same({ "", "[technology=iron]", ", ", "[technology=steel]" }, args[1])
      assert.are.same({ "iron", "steel", "target" }, new_queue)
    end)
  end)
end)
