-- lib/temporary_request_editor.lua
local TemporaryRequestAction = require("lib.actions.temporary_request_action")
local TemporaryRequestEditorLogic = require("lib.temporary_request_editor_logic")

local TemporaryRequestEditor = {}

local FRAME_NAME = "quidquid-temporary-request-editor-frame"
local CONTENT_NAME = "quidquid-temporary-request-editor-content"
local QUALITY_ROW_NAME = "quidquid-temporary-request-editor-quality-row"
local QUALITY_RADIO_PREFIX = "quidquid-temporary-request-editor-quality-"
local QUANTITY_ROW_NAME = "quidquid-temporary-request-editor-quantity-row"
local TEXTFIELD_NAME = "quidquid-temporary-request-editor-textfield"
local MINUS_STACK_BUTTON_NAME = "quidquid-temporary-request-editor-minus-stack-button"
local PLUS_STACK_BUTTON_NAME = "quidquid-temporary-request-editor-plus-stack-button"
local BUTTON_ROW_NAME = "quidquid-temporary-request-editor-button-row"
local CONFIRM_BUTTON_NAME = "quidquid-temporary-request-editor-confirm-button"

local RESERVED_QUALITY_NAME = "quality-unknown"

local DEFAULT_FONT_COLOR = {r = 0, g = 0, b = 0}

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

-- [item=..,quality=..] renders the item's icon tinted/badged for that quality -- the
-- window title updates this whenever the selected quality changes (see select_quality).
local function title_caption(item_name, quality)
  return { "", "[item=" .. item_name .. ",quality=" .. quality .. "] ", prototypes.item[item_name].localised_name }
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

-- helpers.evaluate_expression raises a Lua error for anything it can't parse (not a
-- typed math expression at all, e.g. "abc") rather than returning a sentinel -- pcall
-- turns that into a plain nil, same "couldn't parse" outcome TemporaryRequestEditorLogic
-- .valid_quantity already treats a nil value as.
local function parse_quantity(text)
  local ok, result = pcall(helpers.evaluate_expression, text)
  if not ok then
    return nil
  end
  return result
end

-- Re-applies the textfield's error/normal style (and the per-instance overrides that a
-- style switch wipes) and the Confirm button's enabled state, based on whether the
-- textfield's current text currently parses to a valid quantity. Called after every
-- programmatic or player-driven change to the textfield's text.
local function refresh_quantity_validity(content)
  local textfield = content[QUANTITY_ROW_NAME][TEXTFIELD_NAME]
  local valid = TemporaryRequestEditorLogic.valid_quantity(parse_quantity(textfield.text))

  textfield.style = valid and "textbox" or "invalid_value_textfield"
  textfield.style.font_color = DEFAULT_FONT_COLOR
  textfield.style.horizontal_align = "center"
  textfield.style.width = 100

  content[BUTTON_ROW_NAME][CONFIRM_BUTTON_NAME].enabled = valid
end

local function set_quantity_controls(content, quantity)
  content[QUANTITY_ROW_NAME][TEXTFIELD_NAME].text = tostring(quantity)
  refresh_quantity_validity(content)
end

function TemporaryRequestEditor.open(player, item_name)
  -- Retriggering the action on a different item while the editor is already open
  -- retargets it to the new item rather than silently doing nothing -- consistent with
  -- Cancel/Escape already treating any unconfirmed edit as safe to discard.
  TemporaryRequestEditor.close(player)

  local item_prototype = prototypes.item[item_name]
  local stack_size = item_prototype.stack_size
  local qualities = available_qualities(player.force)

  local frame = player.gui.screen.add{
    type = "frame",
    name = FRAME_NAME,
    direction = "vertical",
    caption = title_caption(item_name, "normal"),
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
        caption = "[quality=" .. quality .. "]",
        state = (quality == "normal"),
        tags = { quidquid_quality = quality },
      }
    end
  end

  local found = existing_request(player, item_name, "normal")
  local quantity = found.quantity or stack_size

  local quantity_row = content.add{ type = "flow", name = QUANTITY_ROW_NAME, direction = "horizontal" }
  -- vertical_align on a flow centers its children within the row's cross-axis, unlike
  -- vertical_align on a single widget (which only centers *that widget's own* inner
  -- content, e.g. its text -- confirmed via the LuaStyle docs after that alone didn't
  -- move the textfield itself).
  quantity_row.style.vertical_align = "center"
  quantity_row.add{
    type = "sprite-button",
    name = MINUS_STACK_BUTTON_NAME,
    sprite = "quidquid-temporary-request-editor-stack-minus",
  }
  local textfield = quantity_row.add{
    type = "textfield",
    name = TEXTFIELD_NAME,
  }
  quantity_row.add{
    type = "sprite-button",
    name = PLUS_STACK_BUTTON_NAME,
    sprite = "quidquid-temporary-request-editor-stack-plus",
  }

  local button_row = content.add{ type = "flow", name = BUTTON_ROW_NAME, direction = "horizontal" }
  local button_spacer = button_row.add{ type = "empty-widget" }
  button_spacer.style.horizontally_stretchable = true
  button_row.add{
    type = "button",
    style = "confirm_button",
    name = CONFIRM_BUTTON_NAME,
    caption = { "quidquid.temporary-request-editor-confirm" },
  }

  set_quantity_controls(content, quantity)

  player.opened = frame
  textfield.focus()
end

function TemporaryRequestEditor.close(player)
  local frame = get_frame(player)
  if frame == nil then
    return
  end
  frame.destroy()
end

local function select_quality(player, quality)
  local frame = get_frame(player)
  if frame == nil then
    return
  end
  local content = frame[CONTENT_NAME]
  local item_name = content.tags.quidquid_item_name
  content.tags = { quidquid_item_name = item_name, quidquid_quality = quality }
  frame.caption = title_caption(item_name, quality)

  local quality_row = content[QUALITY_ROW_NAME]
  if quality_row ~= nil then
    for _, radio in ipairs(quality_row.children) do
      radio.state = (radio.tags.quidquid_quality == quality)
    end
  end

  local item_prototype = prototypes.item[item_name]
  local found = existing_request(player, item_name, quality)
  local quantity = found.quantity or item_prototype.stack_size
  set_quantity_controls(content, quantity)
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

function TemporaryRequestEditor.confirm(player)
  local content = content_of(player)
  if content == nil then
    return
  end
  local item_name = content.tags.quidquid_item_name
  local quality = content.tags.quidquid_quality
  local item_prototype = prototypes.item[item_name]
  local quantity = parse_quantity(content[QUANTITY_ROW_NAME][TEXTFIELD_NAME].text)
  -- The Confirm button is disabled whenever this is false, but the "E" shortcut
  -- (on_confirm_key) bypasses button state entirely, so this guard is still needed here.
  if not TemporaryRequestEditorLogic.valid_quantity(quantity) then
    return
  end

  TemporaryRequestEditor.close(player)

  local point = TemporaryRequestAction.logistic_point_for(player)
  if point == nil then
    return
  end

  local already_have = player.character.get_item_count({ name = item_name, quality = quality })
  local action = TemporaryRequestEditorLogic.decide_confirm_action(quantity, already_have)

  if action == "set" then
    local section = TemporaryRequestAction.get_or_create_section(point)
    local existing = {}
    for i = 1, section.filters_count do
      existing[i] = section.get_slot(i)
    end
    local slot_index = TemporaryRequestAction.find_slot_index(existing, item_name, quality)
    section.set_slot(slot_index, {
      value = { type = "item", name = item_name, quality = quality },
      min = quantity,
    })
    player.create_local_flying_text({
      text = { "quidquid.action-temporary-request-created", item_name, quality, item_prototype.localised_name, quantity },
      create_at_cursor = true,
    })
    return
  end

  local section = TemporaryRequestAction.find_existing_section(point)
  local cleared = false
  if section ~= nil then
    local existing = {}
    for i = 1, section.filters_count do
      existing[i] = section.get_slot(i)
    end
    local slot_index = TemporaryRequestAction.find_slot_index(existing, item_name, quality)
    if slot_index <= #existing then
      section.clear_slot(slot_index)
      cleared = true
    end
  end

  -- Quantity 0 with nothing to remove is a genuine no-op -- unlike "already satisfied",
  -- there's no useful outcome to report, so stay silent rather than claim a removal that
  -- didn't happen.
  if action == "remove_zero" and not cleared then
    return
  end

  local message_key = (action == "remove_zero")
    and "quidquid.action-temporary-request-removed"
    or "quidquid.action-temporary-request-already-satisfied"
  player.create_local_flying_text({
    text = { message_key, item_name, quality, item_prototype.localised_name },
    create_at_cursor = true,
  })
end

function TemporaryRequestEditor.on_gui_click(event)
  local element = event.element
  if element == nil or not element.valid then
    return
  end
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end

  if element.name == MINUS_STACK_BUTTON_NAME or element.name == PLUS_STACK_BUTTON_NAME then
    local content = content_of(player)
    if content == nil then
      return
    end
    local item_name = content.tags.quidquid_item_name
    local stack_size = prototypes.item[item_name].stack_size
    local textfield = content[QUANTITY_ROW_NAME][TEXTFIELD_NAME]
    local current = parse_quantity(textfield.text) or 0
    local next_quantity
    if element.name == PLUS_STACK_BUTTON_NAME then
      next_quantity = TemporaryRequestEditorLogic.next_stack_multiple(current, stack_size)
    else
      next_quantity = TemporaryRequestEditorLogic.previous_stack_multiple(current, stack_size)
    end
    set_quantity_controls(content, next_quantity)
  elseif element.name == CONFIRM_BUTTON_NAME then
    TemporaryRequestEditor.confirm(player)
  end
end

function TemporaryRequestEditor.on_gui_text_changed(event)
  local element = event.element
  if element == nil or not element.valid or element.name ~= TEXTFIELD_NAME then
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
  refresh_quantity_validity(content)
end

function TemporaryRequestEditor.on_gui_closed(event)
  if event.element == nil or not event.element.valid or event.element.name ~= FRAME_NAME then
    return
  end
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end
  TemporaryRequestEditor.close(player)
end

-- Wired to the "E" custom-input so it actually does what confirm_button's own baked-in
-- tooltip ("Confirm (E)") promises. confirm() already no-ops safely if this player's
-- editor isn't open (content_of returns nil), so no extra guard is needed here.
function TemporaryRequestEditor.on_confirm_key(event)
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end
  TemporaryRequestEditor.confirm(player)
end

return TemporaryRequestEditor
