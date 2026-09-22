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

return TechnologyPrerequisites
