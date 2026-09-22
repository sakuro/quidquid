local rich_text = require("lib.rich_text")

local TechnologyPrerequisites = {}

local INFINITE_LEVEL = 4294967295

-- The most prerequisites that could ever actually fit in the queue alongside
-- the target technology itself (queue + prerequisites + target <=
-- MAX_QUEUE_SIZE from lib/actions/research_queue_action.lua), reused here as
-- technology_list_caption's display cap so the number means something
-- concrete rather than being an arbitrary readability guess. (Coincidentally
-- also 6 in lib/temporary_request_editor.lua's MAX_LISTED_INGREDIENTS --
-- that's an unrelated number from an unrelated domain; don't derive one from
-- the other.)
local MAX_LISTED_TECHNOLOGIES = 6

function TechnologyPrerequisites.is_multi_level(technology)
  local max_level = technology.prototype.max_level
  return max_level == INFINITE_LEVEL or max_level == "infinite" or type(max_level) == "number" and max_level > 1
end

function TechnologyPrerequisites.technology_icon(technology)
  return "[technology=" .. technology.name .. "]"
end

function TechnologyPrerequisites.technology_name(technology, level)
  local name = { "", technology.localised_name }
  if TechnologyPrerequisites.is_multi_level(technology) then
    table.insert(name, " ")
    table.insert(name, level or technology.level)
  end
  return name
end

function TechnologyPrerequisites.technology_list_caption(technologies)
  return rich_text.icon_list_caption(
    technologies,
    TechnologyPrerequisites.technology_icon,
    MAX_LISTED_TECHNOLOGIES,
    "quidquid.action-research-queue-technology-list-more"
  )
end

-- Returns unresearched, unqueued prerequisites in dependency order and all trigger
-- technologies found in the prerequisite graph.
function TechnologyPrerequisites.collect_prerequisites(technology, queued)
  local prerequisites = {}
  local triggers = {}
  local visited = {}

  local function visit(current)
    if current.researched or queued[current.name] or visited[current.name] then
      return
    end
    visited[current.name] = true

    local names = {}
    for name in pairs(current.prerequisites) do
      table.insert(names, name)
    end
    table.sort(names)
    for _, name in ipairs(names) do
      visit(current.prerequisites[name])
    end

    if current ~= technology then
      if current.prototype.research_trigger ~= nil then
        table.insert(triggers, current)
      else
        table.insert(prerequisites, current)
      end
    end
  end

  visit(technology)
  return prerequisites, triggers
end

-- Direct (not transitive) prerequisite check, mirroring UltimateResearchQueue's
-- are_prereqs_satisfied (raiguard/UltimateResearchQueue, research-queue.lua).
-- technology.prerequisites is direct-only -- collect_prerequisites above needs
-- to recurse through it manually to reach indirect prerequisites, which
-- wouldn't be necessary if it already returned the full transitive set.
function TechnologyPrerequisites.direct_prerequisites_researched(technology)
  for _, prerequisite in pairs(technology.prerequisites) do
    if not prerequisite.researched then
      return false
    end
  end
  return true
end

-- queued_names is a {[technology_name]=true} set built by the caller from
-- force.research_queue. A technology's prerequisites count as "on track" here
-- if every unresearched one is already queued -- a trigger technology can
-- never be queued (confirmed: ResearchQueueAction.resolve_enqueue refuses to
-- queue one), so an unresearched trigger prerequisite always makes this false.
function TechnologyPrerequisites.direct_prerequisites_queued(technology, queued_names)
  for _, prerequisite in pairs(technology.prerequisites) do
    if not prerequisite.researched then
      if prerequisite.prototype.research_trigger ~= nil then
        return false
      end
      if not queued_names[prerequisite.name] then
        return false
      end
    end
  end
  return true
end

-- Confirmed over RCON against a real save (destroyer, blocked on the
-- unresearched, unqueued military-4) that this -- not LuaTechnology.enabled,
-- which does not track prerequisite completion -- is what distinguishes
-- vanilla's own tech-tree states. Matches UltimateResearchQueue's
-- get_research_state, minus its "disabled" state (not needed: quidquid's
-- candidates are already filtered to visible technologies).
function TechnologyPrerequisites.classify_state(technology, queued_names)
  if technology.researched then
    return "researched"
  end
  if TechnologyPrerequisites.direct_prerequisites_researched(technology) then
    return "available"
  end
  if TechnologyPrerequisites.direct_prerequisites_queued(technology, queued_names) then
    return "conditionally_available"
  end
  return "not_available"
end

return TechnologyPrerequisites
