-- lib/temporary_request_editor.lua
local TemporaryRequestAction = require("lib.actions.temporary_request_action")
local TemporaryRequestEditorLogic = require("lib.temporary_request_editor_logic")

local TemporaryRequestEditor = {}

local FRAME_NAME = "quidquid-temporary-request-editor-frame"
local CONTENT_NAME = "quidquid-temporary-request-editor-content"
local QUALITY_ROW_NAME = "quidquid-temporary-request-editor-quality-row"
local QUALITY_RADIO_PREFIX = "quidquid-temporary-request-editor-quality-"
local QUANTITY_ROW_NAME = "quidquid-temporary-request-editor-quantity-row"
local SLIDER_NAME = "quidquid-temporary-request-editor-slider"
local TEXTFIELD_NAME = "quidquid-temporary-request-editor-textfield"
local STACK_BUTTON_NAME = "quidquid-temporary-request-editor-stack-button"
local BUTTON_ROW_NAME = "quidquid-temporary-request-editor-button-row"
local CONFIRM_BUTTON_NAME = "quidquid-temporary-request-editor-confirm-button"
local CANCEL_BUTTON_NAME = "quidquid-temporary-request-editor-cancel-button"

local SLIDER_MAX_STACKS = 10
local RESERVED_QUALITY_NAME = "quality-unknown"

local DEFAULT_FONT_COLOR = {r = 255, g = 255, b = 255}
local OVERFLOW_FONT_COLOR = {r = 255, g = 142, b = 42}

local function get_frame(player)
  return player.gui.screen[FRAME_NAME]
end

local function content_of(player)
  local frame = get_frame(player)
  if frame == nil then
    return nil
  end
  return frame[CONTENT_NAME]
end

-- Confirmed empirically: `prototypes.quality` always has at least these two reserved
-- entries (`normal`, `quality-unknown`) even with Space Age disabled; any other entry
-- only exists when the Quality system is actually active.
local function quality_system_active()
  for name, _ in pairs(prototypes.quality) do
    if name ~= "normal" and name ~= RESERVED_QUALITY_NAME then
      return true
    end
  end
  return false
end

-- Reads prototypes/force state -- stays untested per this project's runtime-code
-- convention, same as is_applicable/logistic_point_for.
local function available_qualities(force)
  if not quality_system_active() then
    return { "normal" }
  end
  local qualities = {}
  for name, _ in pairs(prototypes.quality) do
    if name ~= RESERVED_QUALITY_NAME and force.is_quality_unlocked(name) then
      table.insert(qualities, name)
    end
  end
  table.sort(qualities, function(a, b)
    return prototypes.quality[a].level < prototypes.quality[b].level
  end)
  return qualities
end

-- Returns {index=.., quantity=..} for item_name+quality's existing request in the shared
-- section, or {index=nil, quantity=nil} if there isn't one yet. Never creates the section
-- (uses find_existing_section, not get_or_create_section) -- just looking shouldn't have
-- side effects.
local function existing_request(player, item_name, quality)
  local point = TemporaryRequestAction.logistic_point_for(player)
  if point == nil then
    return { index = nil, quantity = nil }
  end
  local section = TemporaryRequestAction.find_existing_section(point)
  if section == nil then
    return { index = nil, quantity = nil }
  end
  local existing = {}
  for i = 1, section.filters_count do
    existing[i] = section.get_slot(i)
  end
  local index = TemporaryRequestAction.find_slot_index(existing, item_name, quality)
  if index > #existing then
    return { index = nil, quantity = nil }
  end
  return { index = index, quantity = existing[index].min }
end

local function set_quantity_controls(content, quantity, stack_size)
  local slider = content[QUANTITY_ROW_NAME][SLIDER_NAME]
  local textfield = content[QUANTITY_ROW_NAME][TEXTFIELD_NAME]
  textfield.text = tostring(quantity)
  if quantity > slider.get_slider_maximum() then
    slider.slider_value = slider.get_slider_maximum()
    textfield.style.font_color = OVERFLOW_FONT_COLOR
  else
    slider.slider_value = quantity
    textfield.style.font_color = DEFAULT_FONT_COLOR
  end
end

function TemporaryRequestEditor.open(player, item_name)
  if get_frame(player) ~= nil then
    return
  end

  local item_prototype = prototypes.item[item_name]
  local stack_size = item_prototype.stack_size
  local qualities = available_qualities(player.force)

  local frame = player.gui.screen.add{
    type = "frame",
    name = FRAME_NAME,
    direction = "vertical",
    caption = item_prototype.localised_name,
  }
  frame.auto_center = true

  local content = frame.add{
    type = "frame",
    name = CONTENT_NAME,
    style = "inside_shallow_frame_with_padding",
    direction = "vertical",
  }
  content.tags = { quidquid_item_name = item_name, quidquid_quality = "normal" }

  if #qualities > 1 then
    local quality_row = content.add{ type = "flow", name = QUALITY_ROW_NAME, direction = "horizontal" }
    for _, quality in ipairs(qualities) do
      quality_row.add{
        type = "radiobutton",
        name = QUALITY_RADIO_PREFIX .. quality,
        caption = prototypes.quality[quality].localised_name,
        state = (quality == "normal"),
        tags = { quidquid_quality = quality },
      }
    end
  end

  local found = existing_request(player, item_name, "normal")
  local quantity = found.quantity or stack_size

  local quantity_row = content.add{ type = "flow", name = QUANTITY_ROW_NAME, direction = "horizontal" }
  quantity_row.add{
    type = "slider",
    name = SLIDER_NAME,
    minimum_value = 0,
    maximum_value = SLIDER_MAX_STACKS * stack_size,
    value_step = stack_size,
    discrete_values = true,
  }
  quantity_row.add{
    type = "textfield",
    name = TEXTFIELD_NAME,
    numeric = true,
    allow_decimal = false,
    allow_negative = false,
  }
  quantity_row.add{
    type = "button",
    name = STACK_BUTTON_NAME,
    caption = { "quidquid.temporary-request-editor-stack-button" },
  }
  set_quantity_controls(content, quantity, stack_size)

  local button_row = content.add{ type = "flow", name = BUTTON_ROW_NAME, direction = "horizontal" }
  button_row.add{
    type = "button",
    name = CONFIRM_BUTTON_NAME,
    caption = { "quidquid.temporary-request-editor-confirm" },
  }
  button_row.add{
    type = "button",
    name = CANCEL_BUTTON_NAME,
    caption = { "quidquid.temporary-request-editor-cancel" },
  }

  player.opened = frame
end

function TemporaryRequestEditor.close(player)
  local frame = get_frame(player)
  if frame == nil then
    return
  end
  frame.destroy()
end

local function select_quality(player, quality)
  local content = content_of(player)
  if content == nil then
    return
  end
  local item_name = content.tags.quidquid_item_name
  content.tags = { quidquid_item_name = item_name, quidquid_quality = quality }

  local quality_row = content[QUALITY_ROW_NAME]
  if quality_row ~= nil then
    for _, radio in ipairs(quality_row.children) do
      radio.state = (radio.tags.quidquid_quality == quality)
    end
  end

  local item_prototype = prototypes.item[item_name]
  local found = existing_request(player, item_name, quality)
  local quantity = found.quantity or item_prototype.stack_size
  set_quantity_controls(content, quantity, item_prototype.stack_size)
end

function TemporaryRequestEditor.on_gui_checked_state_changed(event)
  local element = event.element
  if element == nil or not element.valid or element.tags.quidquid_quality == nil then
    return
  end
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end
  select_quality(player, element.tags.quidquid_quality)
end

function TemporaryRequestEditor.on_gui_value_changed(event)
  local element = event.element
  if element == nil or not element.valid or element.name ~= SLIDER_NAME then
    return
  end
  local textfield = element.parent[TEXTFIELD_NAME]
  textfield.text = tostring(element.slider_value)
  textfield.style.font_color = DEFAULT_FONT_COLOR
end

function TemporaryRequestEditor.on_gui_text_changed(event)
  local element = event.element
  if element == nil or not element.valid or element.name ~= TEXTFIELD_NAME then
    return
  end
  local quantity = tonumber(element.text) or 0
  local slider = element.parent[SLIDER_NAME]
  if quantity > slider.get_slider_maximum() then
    slider.slider_value = slider.get_slider_maximum()
    element.style.font_color = OVERFLOW_FONT_COLOR
  else
    slider.slider_value = quantity
    element.style.font_color = DEFAULT_FONT_COLOR
  end
end

function TemporaryRequestEditor.on_gui_click(event)
  local element = event.element
  if element == nil or not element.valid or element.name ~= STACK_BUTTON_NAME then
    return
  end
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end
  local content = content_of(player)
  if content == nil then
    return
  end
  local item_name = content.tags.quidquid_item_name
  local stack_size = prototypes.item[item_name].stack_size
  local textfield = content[QUANTITY_ROW_NAME][TEXTFIELD_NAME]
  local current = tonumber(textfield.text) or 0
  local next_quantity = TemporaryRequestEditorLogic.next_stack_multiple(current, stack_size)
  set_quantity_controls(content, next_quantity, stack_size)
end

return TemporaryRequestEditor
