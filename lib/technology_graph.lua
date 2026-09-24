local TechnologyGraph = {}

--- A plain-Lua mirror of a force's technology graph, with prerequisites linked as
--- node references.
---
--- It holds the fields the prerequisite traversal and TechnologySource.annotate read
--- off a LuaTechnology. Building it costs one pass over the collection; every
--- traversal afterwards is plain table lookups instead of crossings of Factorio's C++
--- boundary, which a prerequisite walk otherwise pays once per (node,
--- ancestor-candidate) pair.
---
--- Not usable with TechnologyPrerequisites.technology_name or .is_multi_level: they
--- read .localised_name, .level and .prototype.max_level, none of which this snapshot
--- copies.
---@param technologies table  anything pairs() yields name -> technology from: a
---  LuaCustomTable in production, a plain table in a spec
---@return table  name -> node { name, researched, saved_progress, prototype, prerequisites }
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
  -- since pairs() order is unspecified. A force holds every technology, so this
  -- lookup always resolves in production; the assert exists so a partial
  -- collection fails loudly at build time rather than silently linking nothing
  -- and producing a graph that walks short.
  for name, technology in pairs(technologies) do
    local prerequisites = nodes[name].prerequisites
    for prerequisite_name in pairs(technology.prerequisites) do
      local node = nodes[prerequisite_name]
      if node == nil then
        error("technology graph: unknown prerequisite " .. prerequisite_name .. " of " .. name)
      end
      prerequisites[prerequisite_name] = node
    end
  end
  return nodes
end

return TechnologyGraph
