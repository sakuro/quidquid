local TechnologyGraph = {}

-- A plain-Lua mirror of a force's technology graph, holding exactly the fields
-- TechnologyPrerequisites and TechnologySource.annotate read off a
-- LuaTechnology. Building it costs one pass over the collection; every
-- traversal afterwards is plain table lookups instead of crossings of
-- Factorio's C++ boundary, which a prerequisite walk otherwise pays once per
-- (node, ancestor-candidate) pair.
--
-- `technologies` is anything pairs() yields name -> technology from: a
-- LuaCustomTable in production, a plain table in a spec.
function TechnologyGraph.build(technologies)
  local nodes = {}
  for name, technology in pairs(technologies) do
    nodes[name] = {
      name = name,
      researched = technology.researched,
      saved_progress = technology.saved_progress,
      prototype = { research_trigger = technology.prototype.research_trigger },
      prerequisites = {},
    }
  end
  -- Second pass: a node's prerequisites may not exist yet during the first one,
  -- since pairs() order is unspecified. A force holds every technology, so each
  -- lookup here resolves; a partial collection would link nil and fail loudly at
  -- traversal time rather than silently producing a short walk.
  for name, technology in pairs(technologies) do
    local prerequisites = nodes[name].prerequisites
    for prerequisite_name in pairs(technology.prerequisites) do
      prerequisites[prerequisite_name] = nodes[prerequisite_name]
    end
  end
  return nodes
end

return TechnologyGraph
