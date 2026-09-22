local flib_dictionary = require("__flib__.dictionary")
local build_candidates = require("lib.sources.prototype_candidate")
local rich_text = require("lib.rich_text")
local TechnologyPrerequisites = require("lib.technology_prerequisites")

local TechnologySource = {}

-- available and conditionally_available share their text (研究可); only the
-- color tells them apart.
local STATE_CAPTIONS = {
  not_available = { text_key = "quidquid.technology-state-not-available", color = "red" },
  conditionally_available = { text_key = "quidquid.technology-state-available", color = "orange" },
  available = { text_key = "quidquid.technology-state-available", color = "yellow" },
  researched = { text_key = "quidquid.technology-state-researched", color = "green" },
}

function TechnologySource.build_caption(state)
  local spec = STATE_CAPTIONS[state]
  return { "", "[color=" .. spec.color .. "]", { spec.text_key }, "[/color]" }
end

-- Defensive bound: no real mine-entity trigger lists more than 2 alternatives
-- today (lithium-processing), but nothing guarantees a mod won't add more --
-- see the design doc's LocalisedString parameter budget section.
local MAX_LISTED_ENTITIES = 10

local function item_icon(item_id_filter)
  return "[item=" .. item_id_filter.name .. "]"
end

local function entity_icon(entity_name)
  return "[entity=" .. entity_name .. "]"
end

-- Maps a research_trigger to core's own [technology-trigger] locale wording
-- (core.cfg) instead of inventing new text -- see the design doc's Tooltip
-- section. Returns nil for craft-fluid (no vanilla/Space Age technology uses
-- it and there is no core.cfg key for it yet -- deferred) and for any
-- unrecognized type.
function TechnologySource.build_trigger_content(research_trigger)
  local trigger_type = research_trigger.type
  if trigger_type == "craft-item" then
    local icon = item_icon(research_trigger.item)
    if research_trigger.count == 1 then
      return { "technology-trigger.craft-item", icon }
    end
    return { "technology-trigger.craft-items", research_trigger.count, icon }
  end
  if trigger_type == "mine-entity" then
    if #research_trigger.entities == 1 then
      return { "technology-trigger.mine-entity", entity_icon(research_trigger.entities[1]) }
    end
    return {
      "technology-trigger.mine-entities",
      rich_text.icon_list_caption(
        research_trigger.entities,
        entity_icon,
        MAX_LISTED_ENTITIES,
        "quidquid.technology-entity-list-more",
        "\n"
      ),
    }
  end
  if trigger_type == "build-entity" then
    return { "technology-trigger.build-entity", entity_icon(research_trigger.entity.name) }
  end
  if trigger_type == "capture-spawner" then
    if research_trigger.entity == nil then
      return { "technology-trigger.capture-any-spawner" }
    end
    return { "technology-trigger.capture-spawner", entity_icon(research_trigger.entity.name) }
  end
  if trigger_type == "create-space-platform" then
    return { "technology-trigger.create-space-platform" }
  end
  if trigger_type == "send-item-to-orbit" then
    return { "technology-trigger.send-item-to-orbit", item_icon(research_trigger.item) }
  end
  if trigger_type == "scripted" then
    return research_trigger.trigger_description
  end
  return nil
end

local function labelled_list_block(label_key, technologies)
  return { label_key, TechnologyPrerequisites.technology_list_caption(technologies) }
end

function TechnologySource.build_tooltip(state, prerequisites, triggers, progress, trigger_content)
  local tooltip = { "" }
  local has_content = false
  if #prerequisites > 0 then
    if has_content then
      table.insert(tooltip, "\n")
    end
    table.insert(tooltip, labelled_list_block("quidquid.technology-missing-prerequisites", prerequisites))
    has_content = true
  end
  if #triggers > 0 then
    if has_content then
      table.insert(tooltip, "\n")
    end
    table.insert(tooltip, labelled_list_block("quidquid.technology-blocked-by-triggers", triggers))
    has_content = true
  end
  if state == "available" and progress > 0 then
    if has_content then
      table.insert(tooltip, "\n")
    end
    table.insert(tooltip, { "quidquid.technology-progress", progress })
    has_content = true
  end
  if trigger_content ~= nil then
    if has_content then
      table.insert(tooltip, "\n")
    end
    table.insert(
      tooltip,
      { "", { "gui-technology-preview.unit-research-trigger-requirements" }, ": ", trigger_content }
    )
    has_content = true
  end
  if not has_content then
    return nil
  end
  return tooltip
end

function TechnologySource.build_annotation(state, prerequisites, triggers, progress, trigger_content)
  return {
    caption = TechnologySource.build_caption(state),
    tooltip = TechnologySource.build_tooltip(state, prerequisites, triggers, progress, trigger_content),
  }
end

local SOURCE_LABEL = { "quidquid.source-technologies" }
local NAMESPACE = "technologies"

local function collect_technologies()
  local technologies = {}
  for _, technology in pairs(prototypes.technology) do
    table.insert(technologies, technology)
  end
  return technologies
end

function TechnologySource.register_dictionary()
  flib_dictionary.new(NAMESPACE)
  for _, technology in ipairs(collect_technologies()) do
    flib_dictionary.add(NAMESPACE, technology.name, technology.localised_name)
  end
end

function TechnologySource.build_candidates(query, technologies, locale, translated_names, include_hidden)
  return build_candidates("technology", "technology", query, technologies, locale, translated_names, include_hidden)
end

local function search(query, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return {}
  end
  local include_hidden = player.mod_settings["quidquid-include-hidden"].value
  local translated_names = flib_dictionary.get(player_index, NAMESPACE) or {}
  return TechnologySource.build_candidates(
    query,
    collect_technologies(),
    player.locale,
    translated_names,
    include_hidden
  )
end

local function queued_names(research_queue)
  local names = {}
  for _, technology in ipairs(research_queue) do
    names[technology.name] = true
  end
  return names
end

-- force.research_progress is only meaningful for the technology actually
-- being researched right now (force.current_research); every other
-- technology's own progress is its saved_progress, which is 0 unless it was
-- previously researched partway and then interrupted.
local function current_progress(force, technology)
  if force.current_research ~= nil and force.current_research.name == technology.name then
    return math.floor(force.research_progress * 100 + 0.5)
  end
  return math.floor(technology.saved_progress * 100 + 0.5)
end

-- Called once per render with only the displayed technology candidates (see
-- Palette.annotate_candidates), so force.research_queue is read and
-- converted to a name set once here rather than per candidate. Unlike the
-- item source's annotate, the skip here isn't gated on controller type --
-- research is force-wide, not tied to a character -- a candidate is only
-- skipped if force.technologies has no entry for it at all.
local function annotate(candidates, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return {}
  end
  local force = player.force
  local queued = queued_names(force.research_queue)

  local annotations = {}
  for index, candidate in ipairs(candidates) do
    local technology = force.technologies[candidate.id]
    if technology ~= nil then
      local state = TechnologyPrerequisites.classify_state(technology, queued)
      local prerequisites, triggers = TechnologyPrerequisites.collect_prerequisites(technology, queued)
      local progress = current_progress(force, technology)
      local trigger_content = nil
      if not technology.researched and technology.prototype.research_trigger ~= nil then
        trigger_content = TechnologySource.build_trigger_content(technology.prototype.research_trigger)
      end
      annotations[index] = TechnologySource.build_annotation(state, prerequisites, triggers, progress, trigger_content)
    end
  end
  return annotations
end

function TechnologySource.register()
  remote.add_interface("quidquid.technology-source", { search = search, annotate = annotate })
  remote.call("quidquid", "register_source", {
    contract_version = 1,
    id = "technologies",
    type = "technology",
    label = SOURCE_LABEL,
    prefixes = { "t", "technology" },
    in_default_search = true,
    interface = "quidquid.technology-source",
  })
end

return TechnologySource
