local TechnologyGraph = require("lib.technology_graph")
local TechnologyPrerequisites = require("lib.technology_prerequisites")

-- TEMPORARY measurement harness for issue #144
-- (docs/superpowers/plans/2026-09-23-prerequisite-graph-snapshot.md). This file
-- and its command are deleted once the comparison is recorded.
local PrereqBench = {}

local REPS = 10

local function queued_names(research_queue)
  local names = {}
  for _, technology in ipairs(research_queue) do
    names[technology.name] = true
  end
  return names
end

-- Sorted so both paths traverse in the same order and the run is reproducible.
local function sorted_names(technologies)
  local names = {}
  for name in pairs(technologies) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

local function walk_all(nodes, names, queued)
  local results = {}
  local closure_sum = 0
  for _, name in ipairs(names) do
    local prerequisites, triggers = TechnologyPrerequisites.collect_prerequisites(nodes[name], queued)
    results[name] = { prerequisites = prerequisites, triggers = triggers }
    closure_sum = closure_sum + #prerequisites + #triggers
  end
  return results, closure_sum
end

-- Compares name sequences, not just lengths: a snapshot that walked the graph in
-- a different order would still match on counts.
local function first_mismatch(live, snapshot, names)
  for _, name in ipairs(names) do
    for _, list in ipairs({ "prerequisites", "triggers" }) do
      local a, b = live[name][list], snapshot[name][list]
      if #a ~= #b then
        return ("%s: %s length %d vs %d"):format(name, list, #a, #b)
      end
      for index, entry in ipairs(a) do
        if entry.name ~= b[index].name then
          return ("%s: %s[%d] %s vs %s"):format(name, list, index, entry.name, b[index].name)
        end
      end
    end
  end
  return nil
end

function PrereqBench.run(player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return
  end
  local force = player.force
  local technologies = force.technologies
  local queued = queued_names(force.research_queue)
  local names = sorted_names(technologies)

  local live_results, closure_sum
  local live = helpers.create_profiler()
  for _ = 1, REPS do
    live_results, closure_sum = walk_all(technologies, names, queued)
  end
  live.stop()
  live.divide(REPS)

  local graph
  local build = helpers.create_profiler()
  for _ = 1, REPS do
    graph = TechnologyGraph.build(technologies)
  end
  build.stop()
  build.divide(REPS)

  local snapshot_results
  local walk = helpers.create_profiler()
  for _ = 1, REPS do
    snapshot_results = walk_all(graph, names, queued)
  end
  walk.stop()
  walk.divide(REPS)

  log({ "", "quidquid-prereq-bench bench.prereq.live ", live })
  log({ "", "quidquid-prereq-bench bench.prereq.snapshot_build ", build })
  log({ "", "quidquid-prereq-bench bench.prereq.snapshot_walk ", walk })
  log(("quidquid-prereq-bench bench.prereq.technologies %d"):format(#names))
  log(("quidquid-prereq-bench bench.prereq.closure_sum %d"):format(closure_sum))

  local mismatch = first_mismatch(live_results, snapshot_results, names)
  if mismatch == nil then
    log("quidquid-prereq-bench bench.prereq.match ok")
    player.print("quidquid-prereq-bench: done, results match, see factorio-current.log")
  else
    log(("quidquid-prereq-bench bench.prereq.match MISMATCH %s"):format(mismatch))
    player.print("quidquid-prereq-bench: MISMATCH, see factorio-current.log")
  end
end

return PrereqBench
