local flib_dictionary = require("__flib__.dictionary")
local build_candidates = require("lib.sources.prototype_candidate")
local rich_text = require("lib.rich_text")
local TechnologyGraph = require("lib.technology_graph")
local TechnologyPrerequisites = require("lib.technology_prerequisites")
local TechnologyUpgradeChain = require("lib.technology_upgrade_chain")

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
-- today (lithium-processing), but nothing guarantees a mod won't add more.
local MAX_LISTED_ENTITIES = 10

local function item_icon(item_id_filter)
  return "[item=" .. item_id_filter.name .. "]"
end

local function entity_icon(entity_name)
  return "[entity=" .. entity_name .. "]"
end

-- Maps a research_trigger to core's own [technology-trigger] locale wording
-- (core.cfg) instead of inventing new text. Returns nil for craft-fluid (no
-- vanilla/Space Age technology uses it and there is no core.cfg key for it
-- yet -- deferred) and for any unrecognized type.
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

-- Prototypes are fixed for the run of a save, so the chain links are derived once
-- and kept here. Deliberately not in `storage`: this is derived data, identical on
-- every peer and rebuilt on load, and saving it would only risk carrying a stale
-- copy across a mod change.
local chain_links = nil

local function technology_chain_links()
  if chain_links == nil then
    chain_links = TechnologyUpgradeChain.build_links(collect_technologies())
  end
  return chain_links
end

-- Drops the upgrade-chain levels the technology screen's grid does not draw as
-- their own tile, so a search answers with the levels that grid offers. The tree
-- view lists every level either way, and include-hidden brings them all back
-- here. Only matched candidates are tested, so the cost scales with the result
-- list rather than with the prototype count.
function TechnologySource.filter_visible(candidates, links, researched, queued)
  local visible = {}
  for _, candidate in ipairs(candidates) do
    if TechnologyUpgradeChain.is_visible(candidate.id, links, researched, queued) then
      table.insert(visible, candidate)
    end
  end
  return visible
end

local function queued_names(research_queue)
  local names = {}
  for _, technology in ipairs(research_queue) do
    names[technology.name] = true
  end
  return names
end

-- Read off the graph rather than the force: the graph pass has already crossed
-- into C++ for every technology, so this one stays in plain Lua.
local function researched_names(graph)
  local names = {}
  for name, node in pairs(graph) do
    if node.researched then
      names[name] = true
    end
  end
  return names
end

-- force.research_progress is meaningful only for the technology currently being
-- researched; every other technology's progress is its own saved_progress, which
-- is 0 unless it was researched partway and then interrupted. ctx carries the
-- current research's name rather than the force itself.
local function current_progress(ctx, technology)
  if ctx.current_research_name == technology.name then
    return math.floor(ctx.research_progress * 100 + 0.5)
  end
  return math.floor(technology.saved_progress * 100 + 0.5)
end

-- The research queue is flattened to a name set, and the current research to its
-- name and a plain progress number. ctx.graph is a plain-Lua snapshot of the
-- force's technologies (see lib/technology_graph.lua), built once here so the
-- per-candidate prerequisite walk never crosses Factorio's C++ boundary. ctx is
-- a snapshot of a moment and is valid for the duration of one search only.
-- Research state is force-wide, so unlike the item source there is no character
-- to check for.
local function gather_annotation_context(player)
  local force = player.force
  return {
    graph = TechnologyGraph.build(force.technologies),
    queued = queued_names(force.research_queue),
    current_research_name = force.current_research and force.current_research.name,
    research_progress = force.research_progress,
  }
end

function TechnologySource.annotate(candidate, ctx)
  local technology = ctx.graph[candidate.id]
  if technology == nil then
    return nil
  end
  local state = TechnologyPrerequisites.classify_state(technology, ctx.queued)
  local prerequisites, triggers = TechnologyPrerequisites.collect_prerequisites(technology, ctx.queued)
  local trigger_content = nil
  if not technology.researched and technology.prototype.research_trigger ~= nil then
    trigger_content = TechnologySource.build_trigger_content(technology.prototype.research_trigger)
  end
  return TechnologySource.build_annotation(
    state,
    prerequisites,
    triggers,
    current_progress(ctx, technology),
    trigger_content
  )
end

-- See the item source for why this annotates every match and why the caller
-- guards it with pcall. Research is force-wide, so unlike the item source there
-- is no character check -- a candidate is skipped only when the force has no
-- technology of that name.
--
-- Filtering and annotating share one ctx: both read the same force snapshot, and
-- building the graph twice per search would be the expensive half of each.
local function refine_candidates(candidates, player, include_hidden)
  local ctx = gather_annotation_context(player)
  local refined = candidates
  if not include_hidden then
    refined =
      TechnologySource.filter_visible(candidates, technology_chain_links(), researched_names(ctx.graph), ctx.queued)
  end
  for _, candidate in ipairs(refined) do
    candidate.annotation = TechnologySource.annotate(candidate, ctx)
  end
  return refined
end

local function search(query, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return {}
  end
  local include_hidden = player.mod_settings["quidquid-include-hidden"].value
  local translated_names = flib_dictionary.get(player_index, NAMESPACE) or {}
  local candidates =
    TechnologySource.build_candidates(query, collect_technologies(), player.locale, translated_names, include_hidden)
  if #candidates == 0 then
    -- The graph build is per-search, not per-candidate: with nothing to annotate, it's pure waste.
    return candidates
  end
  -- On failure the unrefined list is still a usable answer -- every match, no
  -- annotations -- so the search degrades instead of coming back empty.
  local ok, refined = pcall(refine_candidates, candidates, player, include_hidden)
  if not ok then
    log(("quidquid: source 'technologies' candidate refinement failed: %s"):format(tostring(refined)))
    return candidates
  end
  return refined
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
