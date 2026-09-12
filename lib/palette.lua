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

local ROW_HEIGHT = 28
local VISIBLE_ROWS = 5

local DEFAULT_FONT_COLOR = {r = 255, g = 255, b = 255}
local ACCENT_FONT_COLOR = {r = 255, g = 142, b = 42}

local highlighted_index = {}
local selection_mode = {}

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
    else
      log(("quidquid: source '%s' search failed: %s"):format(tostring(source.id), tostring(candidates)))
    end
  end
  return PaletteLogic.merge_candidates(results, DISPLAY_LIMIT)
end

local function row_caption(candidate)
  return {"", "[img=", candidate.icon, "] ", candidate.label}
end

local function build_candidate_button(pane, candidate, is_highlighted)
  local button = pane.add{
    type = "button",
    style = "transparent_button",
    caption = row_caption(candidate),
    tags = { quidquid_candidate = candidate },
  }
  button.style.horizontally_stretchable = true
  button.style.horizontal_align = "left"
  button.style.hovered_font_color = ACCENT_FONT_COLOR
  button.style.font_color = is_highlighted and ACCENT_FONT_COLOR or DEFAULT_FONT_COLOR
end

local function clear_candidates(player)
  local pane = results_pane(player)
  if pane == nil then
    return
  end
  pane.clear()
  highlighted_index[player.index] = nil
end

local function render_candidates(player, candidates)
  local pane = results_pane(player)
  if pane == nil then
    return
  end
  pane.clear()
  for index, candidate in ipairs(candidates) do
    build_candidate_button(pane, candidate, index == 1)
  end
  highlighted_index[player.index] = #candidates > 0 and 1 or nil
end

local function apply_highlight(player)
  local pane = results_pane(player)
  if pane == nil then
    return
  end
  local index = highlighted_index[player.index]
  for i, row in ipairs(pane.children) do
    row.style.font_color = (i == index) and ACCENT_FONT_COLOR or DEFAULT_FONT_COLOR
  end
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

  local results_scroll_pane = frame.add{
    type = "scroll-pane",
    name = RESULTS_NAME,
    direction = "vertical",
  }
  results_scroll_pane.style.height = ROW_HEIGHT * VISIBLE_ROWS

  player.opened = frame
  frame[INPUT_NAME].focus()
end

function Palette.close(player)
  local frame = get_frame(player)
  if frame == nil then
    return
  end
  highlighted_index[player.index] = nil
  selection_mode[player.index] = nil
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
