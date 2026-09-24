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

--- True for an infinite technology -- one whose same prototype can be queued again
--- for the next level.
---
--- Confirmed via RCON against a real save: a finite technology's max_level always
--- equals its own level, whether it's single-level (e.g. automation) or one prototype
--- in an upgrade = true numbered family (e.g. braking-force-4: level = 4, max_level =
--- 4). Only a genuine infinite technology reports a max_level independent of (and
--- always greater than) its current level -- that's what actually makes re-adding the
--- same prototype to the queue mean "the next level."
---@param technology LuaTechnology  .prototype.max_level is read
---@return boolean
function TechnologyPrerequisites.is_multi_level(technology)
  local max_level = technology.prototype.max_level
  return max_level == INFINITE_LEVEL or max_level == "infinite"
end

--- The technology's rich-text icon tag.
---@param technology LuaTechnology
---@return string
function TechnologyPrerequisites.technology_icon(technology)
  return "[technology=" .. technology.name .. "]"
end

--- The technology's display name, with the level appended for an infinite one.
---
--- Only an infinite technology gets a level: for a finite one the number is already
--- part of its own name (braking-force-4), so appending it would read "4 4".
---@param technology LuaTechnology  .localised_name and .level are read
---@param level number|nil  the level to show, defaulting to the technology's current one
---@return table  a LocalisedString
function TechnologyPrerequisites.technology_name(technology, level)
  local name = { "", technology.localised_name }
  if TechnologyPrerequisites.is_multi_level(technology) then
    table.insert(name, " ")
    table.insert(name, level or technology.level)
  end
  return name
end

--- A capped icon list naming technologies, for a tooltip or a message.
---
--- The cap is the most prerequisites that could ever fit in the queue alongside the
--- target itself, so the number means something concrete rather than being a
--- readability guess.
---@param technologies table  array of LuaTechnology
---@return table  a LocalisedString
function TechnologyPrerequisites.technology_list_caption(technologies)
  return rich_text.icon_list_caption(
    technologies,
    TechnologyPrerequisites.technology_icon,
    MAX_LISTED_TECHNOLOGIES,
    "quidquid.action-research-queue-technology-list-more"
  )
end

--- Walks the prerequisite graph for what would have to be researched first.
---
--- Prerequisites come back in dependency order, so queueing them in order is valid.
--- Trigger technologies are returned separately because they cannot be queued at all
--- -- the caller reports them instead. Names are sorted at each step, so the order
--- does not depend on pairs().
---@param technology table  a node from TechnologyGraph.build, or a LuaTechnology
---@param queued table  name set of already-queued technologies, treated as done
---@return table  unresearched, unqueued, non-trigger prerequisites in dependency order
---@return table  trigger technologies found anywhere in the graph
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

--- True when every direct prerequisite is researched.
---
--- Direct only: technology.prerequisites holds just those, which is why
--- collect_prerequisites has to recurse through it to reach indirect ones.
---@param technology table  a graph node or LuaTechnology
---@return boolean
function TechnologyPrerequisites.direct_prerequisites_researched(technology)
  for _, prerequisite in pairs(technology.prerequisites) do
    if not prerequisite.researched then
      return false
    end
  end
  return true
end

--- True when every direct prerequisite is either researched or already queued.
---
--- A trigger technology can never be queued (confirmed:
--- ResearchQueueAction.resolve_enqueue refuses to queue one), so an unresearched
--- trigger prerequisite always makes this false.
---@param technology table  a graph node or LuaTechnology
---@param queued_names table  name set built by the caller from force.research_queue
---@return boolean
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

--- Classifies a technology the way vanilla's own tech tree does.
---
--- Confirmed over RCON against a real save that prerequisite completion -- not
--- LuaTechnology.enabled, which does not track it -- is what distinguishes those
--- states.
---@param technology table  a graph node or LuaTechnology
---@param queued_names table  name set built by the caller from force.research_queue
---@return string  "researched", "available", "conditionally_available" or "not_available"
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
