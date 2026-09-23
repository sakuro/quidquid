local TechnologyGraph = require("lib.technology_graph")
local TechnologyPrerequisites = require("lib.technology_prerequisites")

-- Shaped like the part of LuaTechnology that TechnologyPrerequisites and
-- TechnologySource.annotate read. Mirrors spec/lib/technology_prerequisites_spec.lua's
-- own helper so the two specs describe the same duck type.
local function technology(name, prerequisite_names, options)
  options = options or {}
  return {
    name = name,
    researched = options.researched or false,
    saved_progress = options.saved_progress or 0,
    prototype = { research_trigger = options.research_trigger },
    prerequisite_names = prerequisite_names or {},
  }
end

-- Turns the flat fixtures above into the linked shape a LuaForce hands out,
-- where prerequisites map to the technology objects themselves.
local function linked(list)
  local technologies = {}
  for _, entry in ipairs(list) do
    technologies[entry.name] = entry
  end
  for _, entry in ipairs(list) do
    entry.prerequisites = {}
    for _, name in ipairs(entry.prerequisite_names) do
      entry.prerequisites[name] = technologies[name]
    end
  end
  return technologies
end

describe("TechnologyGraph", function()
  describe(".build", function()
    it("copies the fields a prerequisite walk and an annotation read", function()
      local trigger = { type = "craft-item", item = { name = "electronic-circuit" }, count = 1 }
      local technologies = linked({
        technology("electronics", nil, { researched = true, saved_progress = 0.25, research_trigger = trigger }),
      })

      local graph = TechnologyGraph.build(technologies)

      assert.are.equal("electronics", graph.electronics.name)
      assert.is_true(graph.electronics.researched)
      assert.are.equal(0.25, graph.electronics.saved_progress)
      assert.are.same(trigger, graph.electronics.prototype.research_trigger)
    end)

    it("links a prerequisite to the graph's own node, not the source technology", function()
      local technologies = linked({
        technology("steel-processing"),
        technology("automation", { "steel-processing" }),
      })

      local graph = TechnologyGraph.build(technologies)

      assert.are.equal(graph["steel-processing"], graph.automation.prerequisites["steel-processing"])
      assert.are_not.equal(technologies["steel-processing"], graph.automation.prerequisites["steel-processing"])
    end)

    it("gives a technology without prerequisites an empty table", function()
      local graph = TechnologyGraph.build(linked({ technology("automation") }))

      assert.are.same({}, graph.automation.prerequisites)
    end)

    it("produces a graph collect_prerequisites walks identically to the source", function()
      local technologies = linked({
        technology("steel-processing"),
        technology("logistics", { "steel-processing" }),
        technology("automation", { "logistics", "steel-processing" }),
      })
      local graph = TechnologyGraph.build(technologies)

      local live_prerequisites = TechnologyPrerequisites.collect_prerequisites(technologies.automation, {})
      local snapshot_prerequisites = TechnologyPrerequisites.collect_prerequisites(graph.automation, {})

      local live_names, snapshot_names = {}, {}
      for index, entry in ipairs(live_prerequisites) do
        live_names[index] = entry.name
      end
      for index, entry in ipairs(snapshot_prerequisites) do
        snapshot_names[index] = entry.name
      end
      assert.are.same({ "steel-processing", "logistics" }, live_names)
      assert.are.same(live_names, snapshot_names)
    end)

    it("walks a trigger prerequisite through the same branch for the source and the snapshot", function()
      local trigger = { type = "craft-item", item = { name = "iron-gear-wheel" }, count = 1 }
      local technologies = linked({
        technology("steel-processing"),
        technology("orbital-launch", nil, { research_trigger = trigger }),
        technology("automation", { "steel-processing", "orbital-launch" }),
      })
      local graph = TechnologyGraph.build(technologies)

      local live_prerequisites, live_triggers =
        TechnologyPrerequisites.collect_prerequisites(technologies.automation, {})
      local snapshot_prerequisites, snapshot_triggers =
        TechnologyPrerequisites.collect_prerequisites(graph.automation, {})

      local function names(list)
        local result = {}
        for index, entry in ipairs(list) do
          result[index] = entry.name
        end
        return result
      end

      assert.are.same({ "steel-processing" }, names(live_prerequisites))
      assert.are.same(names(live_prerequisites), names(snapshot_prerequisites))
      assert.are.same({ "orbital-launch" }, names(live_triggers))
      assert.are.same(names(live_triggers), names(snapshot_triggers))
    end)

    it("returns an empty table for an empty collection", function()
      assert.are.same({}, TechnologyGraph.build({}))
    end)

    it("raises when a technology names a prerequisite absent from the collection", function()
      -- Built directly rather than through linked(): linked() resolves
      -- prerequisite_names via technologies[name], so an unknown name would
      -- resolve to nil and assigning prerequisites[name] = nil creates no
      -- entry at all -- it could never reach build()'s assert. This bypasses
      -- that fixture-building step to construct the case build() itself must
      -- reject: a prerequisites key with no matching node in the collection.
      local technologies = {
        automation = technology("automation", { "missing-technology" }),
      }
      technologies.automation.prerequisites = { ["missing-technology"] = true }

      assert.has_error(function()
        TechnologyGraph.build(technologies)
      end)
    end)
  end)
end)
