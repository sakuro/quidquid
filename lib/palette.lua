-- lib/palette.lua
local PaletteLogic = require("lib.palette_logic")
local RemoteCaller = require("lib.remote_caller")

local Palette = {}

local registry = nil

function Palette.init(registry_instance)
  registry = registry_instance
end

local FRAME_NAME = "quidquid-palette-frame"
local INPUT_NAME = "quidquid-palette-input"
local RESULTS_NAME = "quidquid-palette-results"
local DISPLAY_LIMIT = 30

local highlighted_index = {}

local function get_frame(player)
  return player.gui.screen[FRAME_NAME]
end

local function results_pane(player)
  local frame = get_frame(player)
  if frame == nil then
    return nil
  end
  return frame[RESULTS_NAME]
end

local function search_all_sources(query, player_index)
  local results = {}
  for _, source in ipairs(registry:default_active_sources()) do
    local ok, candidates = pcall(remote.call, source.interface, "search", query, player_index, nil)
    if ok then
      table.insert(results, candidates)
    end
  end
  return PaletteLogic.merge_candidates(results, DISPLAY_LIMIT)
end

local function row_caption(index, candidate, is_highlighted)
  local badge = PaletteLogic.badge_number(index)
  local marker = is_highlighted and "\xe2\x96\xb6 " or ""
  if badge ~= nil then
    return {"", marker, "[img=", candidate.icon, "] ", tostring(badge), ". ", candidate.label}
  end
  return {"", marker, "[img=", candidate.icon, "] ", candidate.label}
end

local function apply_highlight(player)
  local pane = results_pane(player)
  if pane == nil then
    return
  end
  local index = highlighted_index[player.index]
  for i, row in ipairs(pane.children) do
    row.caption = row_caption(i, row.tags.quidquid_candidate, i == index)
  end
end

local function build_candidate_button(pane, index, candidate, is_highlighted)
  pane.add{
    type = "button",
    caption = row_caption(index, candidate, is_highlighted),
    tags = { quidquid_candidate = candidate },
  }
end

local function render_candidates(player, candidates)
  local pane = results_pane(player)
  if pane == nil then
    return
  end
  pane.clear()
  for index, candidate in ipairs(candidates) do
    build_candidate_button(pane, index, candidate, index == 1)
  end
  highlighted_index[player.index] = 1
end

function Palette.open(player)
  if get_frame(player) ~= nil then
    return
  end

  local frame = player.gui.screen.add{
    type = "frame",
    name = FRAME_NAME,
    direction = "vertical",
  }
  frame.auto_center = true

  frame.add{
    type = "textfield",
    name = INPUT_NAME,
  }

  frame.add{
    type = "scroll-pane",
    name = RESULTS_NAME,
    direction = "vertical",
  }

  player.opened = frame
  frame[INPUT_NAME].focus()
  render_candidates(player, search_all_sources("", player.index))
end

function Palette.close(player)
  local frame = get_frame(player)
  if frame == nil then
    return
  end
  highlighted_index[player.index] = nil
  frame.destroy()
end

function Palette.toggle(player)
  if get_frame(player) ~= nil then
    Palette.close(player)
  else
    Palette.open(player)
  end
end

return Palette
