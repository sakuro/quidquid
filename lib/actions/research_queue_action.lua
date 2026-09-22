local rich_text = require("lib.rich_text")

local ResearchQueueAction = {}

-- LuaForce.research_queue's length cap. Neither the Lua API docs nor the
-- wiki document this limit; it was determined by observing in-game that the
-- engine refuses to queue a research past the 7th queue slot. Re-verify
-- in-game if this ever needs to change.
local MAX_QUEUE_SIZE = 7
local INFINITE_LEVEL = 4294967295

-- The most prerequisites that could ever actually fit in the queue alongside
-- the target technology itself (queue + prerequisites + target <=
-- MAX_QUEUE_SIZE), reused here as technology_list_caption's display cap so the
-- number means something concrete rather than being an arbitrary
-- readability guess. (Coincidentally also 6 in
-- lib/temporary_request_editor.lua's MAX_LISTED_INGREDIENTS -- that's an
-- unrelated number from an unrelated domain; don't derive one from the
-- other.)
local MAX_LISTED_TECHNOLOGIES = MAX_QUEUE_SIZE - 1

local function is_level_based(technology)
  local max_level = technology.prototype.max_level
  return max_level == INFINITE_LEVEL or max_level == "infinite" or type(max_level) == "number" and max_level > 1
end

-- The icon and name are reported as separate flying-text arguments (__1__, __2__)
-- rather than one fused caption, matching how the temporary-request editor's own
-- confirm messages cite an item/recipe -- see ActionDispatch.run's flying text.
local function technology_icon(technology)
  return "[technology=" .. technology.name .. "]"
end

ResearchQueueAction.technology_icon = technology_icon

local function technology_name(technology, level)
  local name = { "", technology.localised_name }
  if is_level_based(technology) then
    table.insert(name, " ")
    table.insert(name, level or technology.level)
  end
  return name
end

ResearchQueueAction.technology_name = technology_name

local function technology_list_caption(technologies)
  return rich_text.icon_list_caption(
    technologies,
    technology_icon,
    MAX_LISTED_TECHNOLOGIES,
    "quidquid.action-research-queue-technology-list-more"
  )
end

ResearchQueueAction.technology_list_caption = technology_list_caption

local function queued_level(queue, technology)
  local level = technology.level
  if not is_level_based(technology) then
    return level
  end
  for _, queued_technology in ipairs(queue) do
    if queued_technology.name == technology.name then
      level = level + 1
    end
  end
  return level
end

ResearchQueueAction.queued_level = queued_level

local function queue_message(queue, target, locale_key, ...)
  return { locale_key, technology_icon(target), technology_name(target, queued_level(queue, target)), ... }
end

local function queued_names(queue)
  local names = {}
  for _, technology in ipairs(queue) do
    names[technology.name] = true
  end
  return names
end

-- Returns unresearched, unqueued prerequisites in dependency order and all trigger
-- technologies found in the prerequisite graph.
function ResearchQueueAction.collect_prerequisites(technology, queued)
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

function ResearchQueueAction.progress_for(force, technology, queue_index)
  if queue_index == 1 then
    return math.floor(force.research_progress * 100 + 0.5)
  end
  return math.floor(technology.saved_progress * 100 + 0.5)
end

local function queue_index(queue, technology)
  if is_level_based(technology) then
    -- Each occurrence represents the next level of an infinite technology.
    return nil
  end
  for i, queued_technology in ipairs(queue) do
    if queued_technology.name == technology.name then
      return i
    end
  end
  return nil
end

ResearchQueueAction.queue_index = queue_index

-- pure, testable: decides what happens when candidate's technology is added to
-- force's research queue. Returns the technology, a locale key, and its message
-- args -- plus the new queue to install when the outcome is an actual enqueue (nil
-- when the outcome is only a message, e.g. already queued/researched/full). Returns
-- nil for a candidate with no matching force technology (near-impossible, since
-- TechnologySource builds candidates from force.technologies directly).
-- is_available only gates on state uniform across every candidate (there is none
-- registered for this action); per-candidate queue eligibility is a runtime fact
-- resolved here and reported by execute, not hidden from the tooltip.
function ResearchQueueAction.resolve_enqueue(force, candidate)
  local technology = force.technologies[candidate.id]
  if technology == nil then
    return nil
  end

  local queue = force.research_queue
  local existing_index = queue_index(queue, technology)
  if existing_index ~= nil then
    local locale_key = existing_index == 1 and "quidquid.action-research-queue-current"
      or "quidquid.action-research-queue-already-queued"
    return technology, locale_key, { ResearchQueueAction.progress_for(force, technology, existing_index) }, nil
  end

  if technology.researched then
    return technology, "quidquid.action-research-queue-already-researched", {}, nil
  end

  if #queue >= MAX_QUEUE_SIZE then
    return technology, "quidquid.action-research-queue-full", {}, nil
  end

  if technology.prototype.research_trigger ~= nil then
    return technology, "quidquid.action-research-queue-trigger", {}, nil
  end

  local queued = queued_names(queue)
  local prerequisites, triggers = ResearchQueueAction.collect_prerequisites(technology, queued)
  if #triggers > 0 then
    return technology, "quidquid.action-research-queue-trigger-prerequisite", { technology_list_caption(triggers) }, nil
  end

  if #queue + #prerequisites + 1 > MAX_QUEUE_SIZE then
    return technology,
      "quidquid.action-research-queue-prerequisite-slots",
      { technology_list_caption(prerequisites) },
      nil
  end

  local new_queue = {}
  for _, queued_technology in ipairs(queue) do
    table.insert(new_queue, queued_technology.name)
  end
  for _, prerequisite in ipairs(prerequisites) do
    table.insert(new_queue, prerequisite.name)
  end
  table.insert(new_queue, technology.name)

  local locale_key = #prerequisites == 0 and "quidquid.action-research-queue-added"
    or "quidquid.action-research-queue-added-with-prerequisites"
  local args = #prerequisites == 0 and {} or { technology_list_caption(prerequisites) }
  return technology, locale_key, args, new_queue
end

local function execute(candidate, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return
  end

  local force = player.force
  local queue = force.research_queue
  local technology, locale_key, args, new_queue = ResearchQueueAction.resolve_enqueue(force, candidate)
  if technology == nil then
    return
  end

  if new_queue ~= nil then
    force.research_queue = new_queue
  end

  player.create_local_flying_text({
    text = queue_message(queue, technology, locale_key, table.unpack(args)),
    create_at_cursor = true,
  })
end

function ResearchQueueAction.register()
  remote.add_interface("quidquid.research-queue-action", { execute = execute })
  remote.call("quidquid", "register_action", {
    contract_version = 1,
    id = "add-to-research-queue",
    types = { "technology" },
    label = { "quidquid.action-add-to-research-queue" },
    input_name = "quidquid-add-to-research-queue",
    interface = "quidquid.research-queue-action",
  })
end

return ResearchQueueAction
