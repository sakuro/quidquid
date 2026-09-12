-- lib/palette.lua
local PaletteLogic = require("lib.palette_logic")
local RemoteCaller = require("lib.remote_caller")

local Palette = {}

local registry = nil

function Palette.init(registry_instance)
  registry = registry_instance
end

local FRAME_NAME = "quidquid-palette-frame"
local CONTENT_NAME = "quidquid-palette-content"
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
  return frame[CONTENT_NAME][RESULTS_NAME]
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
  pane.style.height = 0
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
  pane.style.height = ROW_HEIGHT * math.min(#candidates, VISIBLE_ROWS)
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
    if i == index then
      pane.scroll_to_element(row)
    end
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
    caption = {"mod-name.quidquid"},
  }
  frame.auto_center = true

  local content_frame = frame.add{
    type = "frame",
    name = CONTENT_NAME,
    style = "inside_shallow_frame_with_padding",
    direction = "vertical",
  }

  content_frame.add{
    type = "textfield",
    name = INPUT_NAME,
  }

  local results_scroll_pane = content_frame.add{
    type = "scroll-pane",
    name = RESULTS_NAME,
    direction = "vertical",
  }
  results_scroll_pane.style.height = 0

  player.opened = frame
  content_frame[INPUT_NAME].focus()
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

local function candidate_at(player, index)
  local pane = results_pane(player)
  if pane == nil or index == nil then
    return nil
  end
  local row = pane.children[index]
  if row == nil then
    return nil
  end
  return row.tags.quidquid_candidate
end

local function dispatch(player, selected_candidate, key)
  if selected_candidate == nil then
    return
  end
  local resolved = registry:resolve_actions(selected_candidate, player.index, RemoteCaller)
  local action = resolved[key]
  if action == nil then
    return
  end
  local ok, err = pcall(remote.call, action.interface, "execute", selected_candidate, {}, player.index)
  if not ok then
    log(("quidquid: action '%s' execute failed: %s"):format(tostring(action.id), tostring(err)))
  end
  Palette.close(player)
end

local function is_palette_input(element)
  return element ~= nil and element.valid and element.name == INPUT_NAME
end

function Palette.on_gui_text_changed(event)
  if not is_palette_input(event.element) then
    return
  end
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end
  selection_mode[player.index] = nil
  if event.text == "" then
    clear_candidates(player)
  else
    render_candidates(player, search_all_sources(event.text, event.player_index))
  end
end

function Palette.on_gui_confirmed(event)
  if not is_palette_input(event.element) then
    return
  end
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end
  local pane = results_pane(player)
  if pane == nil or #pane.children == 0 then
    return
  end
  selection_mode[player.index] = true
  pane.focus()
end

function Palette.on_action_key(event)
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end
  if not selection_mode[player.index] then
    return
  end
  local candidate = candidate_at(player, highlighted_index[player.index])
  dispatch(player, candidate, event.input_name)
end

function Palette.on_gui_click(event)
  local element = event.element
  if element == nil or not element.valid or element.tags.quidquid_candidate == nil then
    return
  end
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end
  dispatch(player, element.tags.quidquid_candidate, "quidquid-confirm")
end

function Palette.on_gui_closed(event)
  if event.element == nil or not event.element.valid or event.element.name ~= FRAME_NAME then
    return
  end
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end
  Palette.close(player)
end

function Palette.on_toggle(event)
  local player = game.get_player(event.player_index)
  if player ~= nil then
    Palette.toggle(player)
  end
end

function Palette.on_select_previous(event)
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end
  if not selection_mode[player.index] then
    return
  end
  local index = highlighted_index[player.index]
  if index ~= nil and index > 1 then
    highlighted_index[player.index] = index - 1
    apply_highlight(player)
  end
end

function Palette.on_select_next(event)
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end
  if not selection_mode[player.index] then
    return
  end
  local pane = results_pane(player)
  if pane == nil then
    return
  end
  local index = highlighted_index[player.index]
  if index ~= nil and index < #pane.children then
    highlighted_index[player.index] = index + 1
    apply_highlight(player)
  end
end

return Palette
