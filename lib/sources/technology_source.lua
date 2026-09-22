local flib_dictionary = require("__flib__.dictionary")
local build_candidates = require("lib.sources.prototype_candidate")
local rich_text = require("lib.rich_text")

local TechnologySource = {}

local STATE_CAPTIONS = {
  not_available = { text_key = "quidquid.technology-state-not-available", color = { r = 255, g = 214, b = 213 } },
  conditionally_available = { text_key = "quidquid.technology-state-available", color = { r = 255, g = 234, b = 206 } },
  available = { text_key = "quidquid.technology-state-available", color = { r = 255, g = 241, b = 183 } },
  researched = { text_key = "quidquid.technology-state-researched", color = { r = 165, g = 255, b = 171 } },
}

-- Colors are flib's technology-slot-style.lua level_range_color values, the
-- same ones UltimateResearchQueue uses for the same four research states --
-- see docs/superpowers/specs/2026-09-22-technology-research-state-design.md.
-- available and conditionally_available share their text (研究可); only the
-- color tells them apart.
function TechnologySource.build_caption(state)
  local spec = STATE_CAPTIONS[state]
  local color = spec.color
  return { "", ("[color=%d,%d,%d]"):format(color.r, color.g, color.b), { spec.text_key }, "[/color]" }
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

function TechnologySource.register()
  remote.add_interface("quidquid.technology-source", { search = search })
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
