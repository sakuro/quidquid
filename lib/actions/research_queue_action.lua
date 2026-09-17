local ResearchQueueAction = {}

-- LuaForce.research_queue's length cap. Neither the Lua API docs nor the
-- wiki document this limit; it was determined by observing in-game that the
-- engine refuses to queue a research past the 7th queue slot. Re-verify
-- in-game if this ever needs to change.
local MAX_QUEUE_SIZE = 7
local INFINITE_LEVEL = 4294967295

local function is_level_based(technology)
  local max_level = technology.prototype.max_level
  return max_level == INFINITE_LEVEL or max_level == "infinite" or type(max_level) == "number" and max_level > 1
end

local function technology_caption(technology, level)
  local caption = { "", "[technology=" .. technology.name .. "] ", technology.localised_name }
  if is_level_based(technology) then
    table.insert(caption, " ")
    table.insert(caption, level or technology.level)
  end
  return caption
end

ResearchQueueAction.technology_caption = technology_caption

local function technology_list(technologies)
  local result = { "" }
  for i, technology in ipairs(technologies) do
    if i > 1 then
      table.insert(result, ", ")
    end
    table.insert(result, "[technology=" .. technology.name .. "]")
  end
  return result
end

ResearchQueueAction.technology_list = technology_list

local function message(target, key, ...)
  local result = { "", technology_caption(target), " ", { key, ... } }
  return result
end

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

local function queue_message(queue, target, key, ...)
  local result = { "", technology_caption(target, queued_level(queue, target)), " ", { key, ... } }
  return result
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

local function execute(candidate, _params, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return
  end

  local force = player.force
  local technology = force.technologies[candidate.id]
  if technology == nil then
    return
  end

  local queue = force.research_queue
  local existing_index = queue_index(queue, technology)
  if existing_index ~= nil then
    local key = existing_index == 1 and "quidquid.action-research-queue-current"
      or "quidquid.action-research-queue-already-queued"
    player.create_local_flying_text({
      text = queue_message(queue, technology, key, ResearchQueueAction.progress_for(force, technology, existing_index)),
      create_at_cursor = true,
    })
    return
  end

  if technology.researched then
    player.create_local_flying_text({
      text = queue_message(queue, technology, "quidquid.action-research-queue-already-researched"),
      create_at_cursor = true,
    })
    return
  end

  if #queue >= MAX_QUEUE_SIZE then
    player.create_local_flying_text({
      text = queue_message(queue, technology, "quidquid.action-research-queue-full"),
      create_at_cursor = true,
    })
    return
  end

  if technology.prototype.research_trigger ~= nil then
    player.create_local_flying_text({
      text = queue_message(queue, technology, "quidquid.action-research-queue-trigger"),
      create_at_cursor = true,
    })
    return
  end

  local queued = queued_names(queue)
  local prerequisites, triggers = ResearchQueueAction.collect_prerequisites(technology, queued)
  if #triggers > 0 then
    player.create_local_flying_text({
      text = queue_message(
        queue,
        technology,
        "quidquid.action-research-queue-trigger-prerequisite",
        technology_list(triggers)
      ),
      create_at_cursor = true,
    })
    return
  end

  if #queue + #prerequisites + 1 > MAX_QUEUE_SIZE then
    player.create_local_flying_text({
      text = queue_message(
        queue,
        technology,
        "quidquid.action-research-queue-prerequisite-slots",
        technology_list(prerequisites)
      ),
      create_at_cursor = true,
    })
    return
  end

  local new_queue = {}
  for _, queued_technology in ipairs(queue) do
    table.insert(new_queue, queued_technology.name)
  end
  for _, prerequisite in ipairs(prerequisites) do
    table.insert(new_queue, prerequisite.name)
  end
  table.insert(new_queue, technology.name)
  force.research_queue = new_queue

  local key = #prerequisites == 0 and "quidquid.action-research-queue-added"
    or "quidquid.action-research-queue-added-with-prerequisites"
  local args = #prerequisites == 0 and {} or { technology_list(prerequisites) }
  player.create_local_flying_text({
    text = queue_message(queue, technology, key, table.unpack(args)),
    create_at_cursor = true,
  })
end

function ResearchQueueAction.register()
  remote.add_interface("quidquid.research-queue-action", { execute = execute })
  remote.call("quidquid", "register_action", {
    version = 1,
    id = "add-to-research-queue",
    types = { "technology" },
    label = { "quidquid.action-add-to-research-queue" },
    key = "quidquid-confirm",
    interface = "quidquid.research-queue-action",
  })
end

return ResearchQueueAction
