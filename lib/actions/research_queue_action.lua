local TechnologyPrerequisites = require("lib.technology_prerequisites")

local ResearchQueueAction = {}

-- LuaForce.research_queue's length cap. Neither the Lua API docs nor the
-- wiki document this limit; it was determined by observing in-game that the
-- engine refuses to queue a research past the 7th queue slot. Re-verify
-- in-game if this ever needs to change.
local MAX_QUEUE_SIZE = 7

--- The level a technology would be researched at if queued now.
---
--- Only an infinite technology can appear in the queue more than once, each occurrence
--- standing for one further level, so for anything else this is just its own level.
--- Exported for spec/lib/actions/research_queue_action_spec.lua.
---@param queue table  force.research_queue
---@param technology LuaTechnology
---@return number
local function queued_level(queue, technology)
  local level = technology.level
  if not TechnologyPrerequisites.is_multi_level(technology) then
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

-- Icon and name are passed as separate message arguments rather than
-- pre-combined into one string: technology_name's level suffix means it
-- returns a nested LocalisedString table, not a plain string, so it can't be
-- concatenated with the icon string via "..".
local function queue_message(queue, target, locale_key, ...)
  return {
    locale_key,
    TechnologyPrerequisites.technology_icon(target),
    TechnologyPrerequisites.technology_name(target, queued_level(queue, target)),
    ...,
  }
end

local function queued_names(queue)
  local names = {}
  for _, technology in ipairs(queue) do
    names[technology.name] = true
  end
  return names
end

--- The research progress to report for a technology, as a whole percent.
---
--- force.research_progress is meaningful only for whatever is being researched right
--- now, which is queue position 1; anything else has its own saved_progress, nonzero
--- only if it was researched partway and then interrupted.
---@param force LuaForce
---@param technology LuaTechnology
---@param queue_position number
---@return number  0-100
function ResearchQueueAction.progress_for(force, technology, queue_position)
  if queue_position == 1 then
    return math.floor(force.research_progress * 100 + 0.5)
  end
  return math.floor(technology.saved_progress * 100 + 0.5)
end

--- Where a technology already sits in the queue, if it does.
---
--- nil for an infinite technology even when it is queued: each occurrence stands for a
--- further level, so "already queued" is not a state it can be in. Exported for the
--- spec.
---@param queue table  force.research_queue
---@param technology LuaTechnology
---@return number|nil
local function queue_index(queue, technology)
  if TechnologyPrerequisites.is_multi_level(technology) then
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

--- Decides what happens when candidate's technology is added to force's research
--- queue, without changing anything.
---
--- Prerequisites are queued along with the technology, so an enqueue can be refused
--- for needing more slots than the queue has left, which is why the whole new queue
--- comes back rather than just the one name.
---
--- is_available only gates on state uniform across every candidate (this action
--- registers none); per-candidate queue eligibility is a runtime fact, resolved here
--- and reported by execute rather than hidden from the tooltip.
---@param force LuaForce
---@param candidate table
---@return LuaTechnology|nil  nil for a candidate with no matching force technology --
---  near-impossible, since TechnologySource builds candidates from force.technologies
---@return string|nil  locale key for the message to show
---@return table|nil  that message's arguments
---@return table|nil  the queue to install, or nil when the outcome is only a message
---  (already queued, researched, full, blocked by a trigger)
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
  local prerequisites, triggers = TechnologyPrerequisites.collect_prerequisites(technology, queued)
  if #triggers > 0 then
    return technology,
      "quidquid.action-research-queue-trigger-prerequisite",
      { TechnologyPrerequisites.technology_list_caption(triggers) },
      nil
  end

  if #queue + #prerequisites + 1 > MAX_QUEUE_SIZE then
    return technology,
      "quidquid.action-research-queue-prerequisite-slots",
      { TechnologyPrerequisites.technology_list_caption(prerequisites) },
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
  local args = #prerequisites == 0 and {} or { TechnologyPrerequisites.technology_list_caption(prerequisites) }
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

--- Adds this action's remote interface and registers it with Quidquid.
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
