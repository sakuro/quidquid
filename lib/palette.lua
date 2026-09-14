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
local INPUT_ROW_NAME = "quidquid-palette-input-row"
local INPUT_NAME = "quidquid-palette-input"
local LOCK_LABEL_NAME = "quidquid-palette-lock-label"
local LOCK_CLOSE_NAME = "quidquid-palette-lock-close"
local RESULTS_NAME = "quidquid-palette-results"
local RESULTS_TABLE_NAME = "quidquid-palette-results-table"
local DISPLAY_LIMIT = 30

local ROW_HEIGHT = 28
local VISIBLE_ROWS = 5
local CONTENT_WIDTH = 400

local DEFAULT_FONT_COLOR = {r = 255, g = 255, b = 255}
local ACCENT_FONT_COLOR = {r = 255, g = 142, b = 42}
local MUTED_FONT_COLOR = {r = 160, g = 160, b = 160}

local function get_frame(player)
  return player.gui.screen[FRAME_NAME]
end

local function content_frame_of(player)
  local frame = get_frame(player)
  if frame == nil then
    return nil
  end
  return frame[CONTENT_NAME]
end

local function results_pane(player)
  local frame = get_frame(player)
  if frame == nil then
    return nil
  end
  return frame[CONTENT_NAME][RESULTS_NAME]
end

local function results_table(player)
  local pane = results_pane(player)
  if pane == nil then
    return nil
  end
  return pane[RESULTS_TABLE_NAME]
end

function Palette.search_all_sources(query, player_index, locked_source)
  local results = {}
  local sources = locked_source and {locked_source} or registry:default_active_sources()
  for _, source in ipairs(sources) do
    local ok, candidates = pcall(remote.call, source.interface, "search", query, player_index, nil)
    if ok then
      local wrapped = {}
      for _, candidate in ipairs(candidates) do
        table.insert(wrapped, { candidate = candidate, source_label = source.label })
      end
      table.insert(results, wrapped)
    else
      log(("quidquid: source '%s' search failed: %s"):format(tostring(source.id), tostring(candidates)))
    end
  end
  return PaletteLogic.merge_candidates(results, DISPLAY_LIMIT)
end

function Palette.row_caption(candidate)
  return {"", "[img=", candidate.icon, "] ", candidate.label}
end

-- __CONTROL__<name>__ is a locale-string placeholder the engine substitutes with the
-- player's actual current key binding for that custom-input (not just its data.lua
-- default -- confirmed this also works for mod-defined custom-inputs, not only builtin
-- game controls). Confirmed empirically that this substitution only happens for text
-- read from an actual locale (.cfg) entry, not for a raw string segment built at
-- runtime and dropped directly into a LocalisedString array -- so each action's hint
-- is its own locale key (`action-<id>-hint`, one per registered action, added
-- alongside that action's own `action-<id>` label), looked up here by id rather than
-- constructed inline. Keys are sorted for a stable, predictable tooltip order.
local function candidate_tooltip(candidate, player_index)
  local resolved = registry:resolve_actions(candidate, player_index, RemoteCaller)
  local keys = {}
  for key, _ in pairs(resolved) do
    table.insert(keys, key)
  end
  if #keys == 0 then
    return nil
  end
  table.sort(keys)

  local tooltip = {""}
  for _, key in ipairs(keys) do
    local definition = resolved[key]
    table.insert(tooltip, definition.label)
    table.insert(tooltip, " (")
    table.insert(tooltip, {"quidquid.action-" .. definition.id .. "-hint"})
    table.insert(tooltip, ")\n")
  end
  return tooltip
end

local function build_candidate_row(pane, wrapped, player_index)
  local button = pane.add{
    type = "button",
    style = "transparent_button",
    caption = Palette.row_caption(wrapped.candidate),
    tooltip = candidate_tooltip(wrapped.candidate, player_index),
    tags = { quidquid_candidate = wrapped.candidate },
  }
  button.style.horizontally_stretchable = true
  button.style.horizontal_align = "left"
  button.style.font_color = DEFAULT_FONT_COLOR
  button.style.hovered_font_color = ACCENT_FONT_COLOR

  local source_label = pane.add{
    type = "label",
    caption = wrapped.source_label,
  }
  source_label.style.horizontal_align = "right"
  source_label.style.font_color = MUTED_FONT_COLOR
end

local function clear_candidates(player)
  local pane = results_pane(player)
  local table_element = results_table(player)
  if pane == nil or table_element == nil then
    return
  end
  table_element.clear()
  pane.style.height = 0
end

local function render_candidates(player, candidates)
  local pane = results_pane(player)
  local table_element = results_table(player)
  if pane == nil or table_element == nil then
    return
  end
  table_element.clear()
  for _, wrapped in ipairs(candidates) do
    build_candidate_row(table_element, wrapped, player.index)
  end
  pane.style.height = nil
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
  content_frame.style.width = CONTENT_WIDTH

  local input_row = content_frame.add{
    type = "flow",
    name = INPUT_ROW_NAME,
    direction = "horizontal",
  }
  input_row.style.horizontally_stretchable = true

  local lock_label = input_row.add{
    type = "label",
    name = LOCK_LABEL_NAME,
    visible = false,
  }
  lock_label.style.vertical_align = "center"

  input_row.add{
    type = "sprite-button",
    name = LOCK_CLOSE_NAME,
    style = "frame_action_button",
    sprite = "utility/close",
    visible = false,
    tags = { quidquid_close_lock = true },
  }

  local input = input_row.add{
    type = "textfield",
    name = INPUT_NAME,
  }
  input.style.width = 0
  input.style.horizontally_stretchable = true

  local results_scroll_pane = content_frame.add{
    type = "scroll-pane",
    name = RESULTS_NAME,
    direction = "vertical",
  }
  results_scroll_pane.style.horizontally_stretchable = true
  results_scroll_pane.style.height = 0
  results_scroll_pane.style.maximal_height = ROW_HEIGHT * VISIBLE_ROWS

  local results_table = results_scroll_pane.add{
    type = "table",
    name = RESULTS_TABLE_NAME,
    column_count = 2,
  }
  results_table.style.horizontally_stretchable = true

  player.opened = frame
  input_row[INPUT_NAME].focus()
end

function Palette.close(player)
  local frame = get_frame(player)
  if frame == nil then
    return
  end
  frame.destroy()
end

function Palette.toggle(player)
  if get_frame(player) ~= nil then
    Palette.close(player)
  else
    Palette.open(player)
  end
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

function Palette.is_palette_input(element)
  return element ~= nil and element.valid and element.name == INPUT_NAME
end

function Palette.trigger_prefix(text)
  if text:sub(-1) ~= " " then
    return nil
  end
  return text:sub(1, -2)
end

local function get_locked_source(player)
  local content = content_frame_of(player)
  if content == nil then
    return nil
  end
  return content.tags.quidquid_locked_source
end

local function lock_to_source(player, source)
  local content = content_frame_of(player)
  if content == nil then
    return
  end
  content.tags = { quidquid_locked_source = source }
  content[INPUT_ROW_NAME][INPUT_NAME].text = ""
  content[INPUT_ROW_NAME][LOCK_LABEL_NAME].caption = source.label
  content[INPUT_ROW_NAME][LOCK_LABEL_NAME].visible = true
  content[INPUT_ROW_NAME][LOCK_CLOSE_NAME].visible = true
  clear_candidates(player)
end

function Palette.on_gui_text_changed(event)
  if not Palette.is_palette_input(event.element) then
    return
  end
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end

  local locked_source = get_locked_source(player)
  if locked_source == nil then
    local prefix = Palette.trigger_prefix(event.text)
    local source = prefix and registry:source_for_prefix(prefix)
    if source ~= nil then
      lock_to_source(player, source)
      return
    end
  end

  if event.text == "" then
    clear_candidates(player)
  else
    render_candidates(player, Palette.search_all_sources(event.text, event.player_index, locked_source))
  end
end

function Palette.on_action_key(event)
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end

  local element = event.element
  if element == nil or not element.valid or element.tags.quidquid_candidate == nil then
    return
  end
  dispatch(player, element.tags.quidquid_candidate, event.input_name)
end

function Palette.on_clear_source_lock(event)
  local element = event.element
  if element == nil or not element.valid or element.tags.quidquid_close_lock == nil then
    return
  end
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end

  local content = content_frame_of(player)
  if content == nil then
    return
  end

  local current_text = content[INPUT_ROW_NAME][INPUT_NAME].text
  content.tags = {}
  content[INPUT_ROW_NAME][LOCK_LABEL_NAME].visible = false
  content[INPUT_ROW_NAME][LOCK_CLOSE_NAME].visible = false

  if current_text == "" then
    clear_candidates(player)
  else
    render_candidates(player, Palette.search_all_sources(current_text, player.index))
  end
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

return Palette
