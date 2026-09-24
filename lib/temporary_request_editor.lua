local TemporaryRequestAction = require("lib.actions.temporary_request_action")
local TemporaryRequestEditorLogic = require("lib.temporary_request_editor_logic")
local rich_text = require("lib.rich_text")

local TemporaryRequestEditor = {}

local FRAME_NAME = "quidquid-temporary-request-editor-frame"
local TITLEBAR_NAME = "quidquid-temporary-request-editor-titlebar"
local TITLE_LABEL_NAME = "quidquid-temporary-request-editor-title-label"
local CANCEL_BUTTON_NAME = "quidquid-temporary-request-editor-cancel"
local CONTENT_NAME = "quidquid-temporary-request-editor-content"
local INPUT_TABLE_NAME = "quidquid-temporary-request-editor-input-table"
local QUALITY_ROW_NAME = "quidquid-temporary-request-editor-quality-row"
local QUALITY_BUTTON_PREFIX = "quidquid-temporary-request-editor-quality-"
local QUANTITY_ROW_NAME = "quidquid-temporary-request-editor-quantity-row"
local TEXTFIELD_NAME = "quidquid-temporary-request-editor-textfield"
local MINUS_BUTTON_NAME = "quidquid-temporary-request-editor-minus-button"
local PLUS_BUTTON_NAME = "quidquid-temporary-request-editor-plus-button"
local BUTTON_ROW_NAME = "quidquid-temporary-request-editor-button-row"
local CONFIRM_BUTTON_NAME = "quidquid-temporary-request-editor-confirm-button"

local UNKNOWN_QUALITY_NAME = "quality-unknown"
local DEFAULT_FONT_COLOR = { r = 0, g = 0, b = 0 }

-- A frame does not clip its children, so a ceiling on the frame alone doesn't
-- keep the title inside it: a long localised name (e.g. Space Age's
-- "Space platform starter pack", longer still in Japanese) renders at its
-- natural width, spilling past the frame's right edge and pushing the close
-- button out of view entirely. The title label needs a ceiling of its own,
-- derived from the frame's: what's left after the frame's padding, the close
-- button, the titlebar flow's spacing, and a sliver of draggable filler. An
-- estimate pending in-game confirmation, not a measured fit.
local FRAME_MAX_WIDTH = 360
local TITLE_MAX_WIDTH = FRAME_MAX_WIDTH - 70

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

local function target_from_content(content)
  return { type = content.tags.quidquid_target_type, name = content.tags.quidquid_target_name }
end

local function target_prototype(target)
  if target.type == "item" then
    return prototypes.item[target.name]
  end
  return prototypes.recipe[target.name]
end

local function quality_system_active()
  for name, _ in pairs(prototypes.quality) do
    if name ~= "normal" and name ~= UNKNOWN_QUALITY_NAME then
      return true
    end
  end
  return false
end

-- A rich-text tag like [item=iron-plate] or [item=iron-plate,quality=legendary],
-- omitting the quality segment entirely when the quality system isn't active --
-- matching the base game's own convention, since there are no player-visible
-- qualities to name in that case.
local function tag_with_quality(type_name, name, quality)
  local suffix = quality_system_active() and ",quality=" .. quality or ""
  return "[" .. type_name .. "=" .. name .. suffix .. "]"
end

local function title_caption(target, quality)
  local prefix = target.type == "item" and "item" or "recipe"
  return {
    "",
    "[virtual-signal=signal-Q] ",
    tag_with_quality(prefix, target.name, quality),
    " ",
    target_prototype(target).localised_name,
  }
end

local function available_qualities(force)
  if not quality_system_active() then
    return { "normal" }
  end
  local qualities = {}
  for name, _ in pairs(prototypes.quality) do
    if name ~= UNKNOWN_QUALITY_NAME and force.is_quality_unlocked(name) then
      table.insert(qualities, name)
    end
  end
  table.sort(qualities, function(a, b)
    return prototypes.quality[a].level < prototypes.quality[b].level
  end)
  return qualities
end

local function recipe_for(player, target)
  return player.force.recipes[target.name]
end

local function quantity_row_of(content)
  return content[INPUT_TABLE_NAME][QUANTITY_ROW_NAME]
end

local function ingredients_for(player, target)
  if target.type == "item" then
    return { { type = "item", name = target.name, amount = 1 } }
  end
  local recipe = recipe_for(player, target)
  return recipe == nil and {} or recipe.ingredients
end

local function existing_section_slots(player)
  local point = TemporaryRequestAction.requester_point_for(player)
  if point == nil then
    return nil
  end
  local section = TemporaryRequestAction.find_existing_section(point)
  if section == nil then
    return nil
  end
  local slots = {}
  for i = 1, section.filters_count do
    slots[i] = section.get_slot(i)
  end
  return slots
end

local function existing_amount(player, target, quality)
  local slots = existing_section_slots(player)
  if slots == nil then
    return nil
  end

  local ingredients = ingredients_for(player, target)
  if target.type == "item" then
    local index = TemporaryRequestAction.find_or_next_slot_index(slots, target.name, quality)
    return index <= #slots and slots[index].min or nil
  end

  local quantities = {}
  for _, ingredient in ipairs(ingredients) do
    if ingredient.type == "item" then
      local index = TemporaryRequestAction.find_or_next_slot_index(slots, ingredient.name, quality)
      if index > #slots then
        return nil
      end
      quantities[ingredient.name] = slots[index].min
    end
  end
  return TemporaryRequestEditorLogic.recipe_craft_count(quantities, ingredients)
end

local QUANTITY_VARIABLES = { k = 1000, M = 1000000 }

local function parse_quantity(text)
  local ok, result = pcall(helpers.evaluate_expression, text, QUANTITY_VARIABLES)
  return ok and result or nil
end

local function refresh_quantity_validity(content)
  local textfield = quantity_row_of(content)[TEXTFIELD_NAME]
  local value = parse_quantity(textfield.text)
  local valid = TemporaryRequestEditorLogic.is_valid_quantity(value)
  textfield.style = valid and "textbox" or "invalid_value_textfield"
  textfield.style.font_color = DEFAULT_FONT_COLOR
  textfield.style.horizontal_align = "center"
  textfield.style.width = 100
  content[BUTTON_ROW_NAME][CONFIRM_BUTTON_NAME].enabled = valid
  quantity_row_of(content)[MINUS_BUTTON_NAME].enabled = valid and value > 0
  quantity_row_of(content)[PLUS_BUTTON_NAME].enabled = valid
end

local function set_quantity_controls(content, quantity)
  quantity_row_of(content)[TEXTFIELD_NAME].text = tostring(quantity)
  refresh_quantity_validity(content)
end

local function target_ingredients(player, target, craft_count, quality)
  return TemporaryRequestEditorLogic.recipe_ingredients(ingredients_for(player, target), craft_count, quality)
end

-- The current actual maximum number of item ingredients any recipe has
-- (fusion-reactor-equipment; confirmed empirically via RCON against base +
-- Space Age + elevated-rails + quality + recycler -- entity ingredient_count
-- gives no useful bound here, since every crafting machine except
-- furnaces/recycler reports 65535, an "effectively unlimited" sentinel, not
-- a real per-machine cap). Chosen so this cap essentially never truncates a
-- real recipe's list today, while still bounding the pathological case the
-- same way MAX_LISTED_TECHNOLOGIES bounds research's dependency graphs.
-- (Coincidentally also 6 in lib/technology_prerequisites.lua's
-- MAX_LISTED_TECHNOLOGIES -- that's an unrelated number from an unrelated
-- domain; don't derive one from the other.)
local MAX_LISTED_INGREDIENTS = 6

local function ingredient_icon(ingredient)
  return tag_with_quality("item", ingredient.name, ingredient.quality)
end

local function ingredient_caption(ingredients)
  return rich_text.icon_list_caption(
    ingredients,
    ingredient_icon,
    MAX_LISTED_INGREDIENTS,
    "quidquid.action-recipe-temporary-request-ingredient-list-more"
  )
end

local function item_caption(target, quality)
  return tag_with_quality("item", target.name, quality)
end

local function recipe_caption(target, quality)
  return tag_with_quality("recipe", target.name, quality)
end

--- Opens the editor for a candidate, prefilled from the player's existing request.
---
--- Closes any editor already open first, so the frame is never built twice. The target
--- and the chosen quality live in the content element's tags rather than in `storage`:
--- the editor is a transient GUI, and the frame going away is exactly when this state
--- should stop existing.
---@param player LuaPlayer
---@param selected_candidate table  an item or recipe candidate
function TemporaryRequestEditor.open(player, selected_candidate)
  local target = { type = selected_candidate.type, name = selected_candidate.id }

  TemporaryRequestEditor.close(player)
  local qualities = available_qualities(player.force)
  local frame = player.gui.screen.add({
    type = "frame",
    name = FRAME_NAME,
    direction = "vertical",
  })
  frame.style.maximal_width = FRAME_MAX_WIDTH
  frame.auto_center = true

  local titlebar = frame.add({ type = "flow", name = TITLEBAR_NAME, direction = "horizontal" })
  titlebar.drag_target = frame
  local title_label = titlebar.add({
    type = "label",
    name = TITLE_LABEL_NAME,
    style = "frame_title",
    caption = title_caption(target, "normal"),
    -- The truncated title drops the tail of the name, so the full one lives in a
    -- tooltip. That needs the label to receive the mouse, which rules out
    -- ignored_by_interaction -- the label would otherwise let clicks fall through
    -- to the titlebar flow that drags the frame. It drags the frame itself instead.
    tooltip = target_prototype(target).localised_name,
  })
  title_label.drag_target = frame
  title_label.style.maximal_width = TITLE_MAX_WIDTH
  -- The ceiling only truncates while the label stays on one line -- frame_title
  -- already is single-line, but the two belong together, so pin it here rather
  -- than lean on that style's default.
  title_label.style.single_line = true
  -- Without this the label keeps its natural width under the titlebar flow's
  -- layout and the ceiling above never bites.
  title_label.style.horizontally_squashable = true
  local titlebar_filler = titlebar.add({
    type = "empty-widget",
    style = "draggable_space_header",
    ignored_by_interaction = true,
  })
  titlebar_filler.style.horizontally_stretchable = true
  titlebar_filler.style.height = 24
  titlebar.add({
    type = "sprite-button",
    name = CANCEL_BUTTON_NAME,
    style = "frame_action_button",
    sprite = "utility/close",
    tooltip = { "quidquid.cancel-tooltip" },
    tags = { quidquid_temporary_request_editor_cancel = true },
  })

  local content = frame.add({
    type = "frame",
    name = CONTENT_NAME,
    style = "inside_shallow_frame_with_padding",
    direction = "vertical",
  })
  content.style.horizontally_stretchable = true
  content.tags = {
    quidquid_target_type = target.type,
    quidquid_target_name = target.name,
    quidquid_quality = "normal",
  }

  local input_table = content.add({
    type = "table",
    name = INPUT_TABLE_NAME,
    column_count = 2,
  })
  input_table.style.horizontally_stretchable = true

  if #qualities > 1 then
    input_table.add({ type = "label", caption = { "quidquid.temporary-request-editor-quality-label" } })
    local quality_row = input_table.add({ type = "flow", name = QUALITY_ROW_NAME, direction = "horizontal" })
    quality_row.style.horizontally_stretchable = true
    quality_row.style.horizontal_align = "center"
    for _, quality in ipairs(qualities) do
      quality_row.add({
        type = "button",
        name = QUALITY_BUTTON_PREFIX .. quality,
        style = "compact_slot_sized_button",
        caption = "[quality=" .. quality .. "]",
        tooltip = prototypes.quality[quality].localised_name,
        toggled = quality == "normal",
        tags = { quidquid_quality = quality },
      })
    end
  end

  local initial_quantity = existing_amount(player, target, "normal")
  if initial_quantity == nil then
    initial_quantity = target.type == "item" and prototypes.item[target.name].stack_size or 1
  end

  input_table.add({
    type = "label",
    caption = {
      target.type == "item" and "quidquid.temporary-request-editor-requested-quantity-label"
        or "quidquid.temporary-request-editor-craft-count-label",
    },
  })
  local quantity_row = input_table.add({ type = "flow", name = QUANTITY_ROW_NAME, direction = "horizontal" })
  quantity_row.style.horizontally_stretchable = true
  quantity_row.style.horizontal_align = "center"
  quantity_row.style.vertical_align = "center"
  quantity_row.add({
    type = "sprite-button",
    name = MINUS_BUTTON_NAME,
    sprite = target.type == "item" and "quidquid-temporary-request-editor-stack-minus" or "virtual-signal/signal-minus",
    tooltip = {
      target.type == "item" and "quidquid.temporary-request-editor-stack-minus-tooltip"
        or "quidquid.temporary-request-editor-quantity-minus-tooltip",
    },
  })
  quantity_row.add({ type = "textfield", name = TEXTFIELD_NAME })
  quantity_row.add({
    type = "sprite-button",
    name = PLUS_BUTTON_NAME,
    sprite = target.type == "item" and "quidquid-temporary-request-editor-stack-plus" or "virtual-signal/signal-plus",
    tooltip = {
      target.type == "item" and "quidquid.temporary-request-editor-stack-plus-tooltip"
        or "quidquid.temporary-request-editor-quantity-plus-tooltip",
    },
  })

  local button_row = content.add({ type = "flow", name = BUTTON_ROW_NAME, direction = "horizontal" })
  button_row.style.horizontally_stretchable = true
  local left_spacer = button_row.add({ type = "empty-widget" })
  left_spacer.style.horizontally_stretchable = true
  button_row.add({
    type = "button",
    style = "green_button",
    name = CONFIRM_BUTTON_NAME,
    caption = {
      target.type == "item" and "quidquid.temporary-request-editor-confirm-item"
        or "quidquid.temporary-request-editor-confirm-recipe",
    },
    tooltip = {
      target.type == "item" and "quidquid.temporary-request-editor-confirm-item-tooltip"
        or "quidquid.temporary-request-editor-confirm-recipe-tooltip",
    },
  })
  local right_spacer = button_row.add({ type = "empty-widget" })
  right_spacer.style.horizontally_stretchable = true

  set_quantity_controls(content, initial_quantity)
  player.opened = frame
  quantity_row_of(content)[TEXTFIELD_NAME].focus()
end

--- Destroys the editor frame if it is open. Safe to call when it is not.
---@param player LuaPlayer
function TemporaryRequestEditor.close(player)
  local frame = get_frame(player)
  if frame ~= nil then
    frame.destroy()
  end
end

local function select_quality(player, quality)
  local frame = get_frame(player)
  if frame == nil then
    return
  end
  local content = frame[CONTENT_NAME]
  local target = target_from_content(content)
  content.tags = {
    quidquid_target_type = target.type,
    quidquid_target_name = target.name,
    quidquid_quality = quality,
  }
  frame[TITLEBAR_NAME][TITLE_LABEL_NAME].caption = title_caption(target, quality)
  local quality_row = content[INPUT_TABLE_NAME][QUALITY_ROW_NAME]
  if quality_row ~= nil then
    for _, radio in ipairs(quality_row.children) do
      radio.toggled = radio.tags.quidquid_quality == quality
    end
  end
  local quantity = existing_amount(player, target, quality)
  if quantity == nil then
    quantity = target.type == "item" and prototypes.item[target.name].stack_size or 1
  end
  set_quantity_controls(content, quantity)
end

local function clear_ingredient_requests(section, existing, ingredients)
  local cleared = false
  for _, ingredient in ipairs(ingredients) do
    local index = TemporaryRequestAction.find_or_next_slot_index(existing, ingredient.name, ingredient.quality)
    if index <= #existing then
      section.clear_slot(index)
      existing[index] = { value = nil }
      cleared = true
    end
  end
  return cleared
end

--- Applies what the player entered: sets, or removes, the temporary request.
---
--- Does nothing at all for an unparseable or negative quantity, which is the same
--- signal the textfield's error background already gives -- no message, because the
--- player is mid-edit rather than mistaken. A quantity of 0, or one the player already
--- holds, removes the request instead of setting it; the decision itself is
--- TemporaryRequestEditorLogic's, which knows nothing about the GUI.
---
--- The frame closes before the section is touched, so the player sees the editor
--- dismiss even if writing the slots then finds no requester point.
---@param player LuaPlayer
function TemporaryRequestEditor.confirm(player)
  local content = content_of(player)
  if content == nil then
    return
  end
  local target = target_from_content(content)
  local quality = content.tags.quidquid_quality
  local quantity = parse_quantity(quantity_row_of(content)[TEXTFIELD_NAME].text)
  if not TemporaryRequestEditorLogic.is_valid_quantity(quantity) then
    return
  end

  local ingredients = target_ingredients(player, target, quantity, quality)
  local satisfied = TemporaryRequestEditorLogic.all_ingredients_satisfied(
    ingredients,
    function(name, ingredient_quality)
      return player.character.get_item_count({ name = name, quality = ingredient_quality })
    end
  )
  local action
  if quantity == 0 then
    action = "remove_zero"
  elseif satisfied then
    action = "remove_satisfied"
  else
    action = "set"
  end

  TemporaryRequestEditor.close(player)
  local point = TemporaryRequestAction.requester_point_for(player)
  if point == nil then
    return
  end

  local section = TemporaryRequestAction.find_existing_section(point)
  local existing = {}
  if section ~= nil then
    for i = 1, section.filters_count do
      existing[i] = section.get_slot(i)
    end
  end

  if action == "set" then
    section = section or TemporaryRequestAction.get_or_create_section(point)
    existing = {}
    for i = 1, section.filters_count do
      existing[i] = section.get_slot(i)
    end
    for _, ingredient in ipairs(ingredients) do
      local index = TemporaryRequestAction.find_or_next_slot_index(existing, ingredient.name, ingredient.quality)
      section.set_slot(index, {
        value = { type = "item", name = ingredient.name, quality = ingredient.quality },
        min = ingredient.amount,
      })
      existing[index] = { value = { name = ingredient.name, quality = ingredient.quality } }
    end
    local message
    if target.type == "item" then
      message = {
        "quidquid.action-item-temporary-request-created",
        item_caption(target, quality),
        target_prototype(target).localised_name,
        quantity,
      }
    else
      message = {
        "quidquid.action-recipe-temporary-request-created",
        recipe_caption(target, quality),
        target_prototype(target).localised_name,
        quantity,
        ingredient_caption(ingredients),
      }
    end
    player.create_local_flying_text({ text = message, create_at_cursor = true })
    return
  end

  local cleared = section ~= nil and clear_ingredient_requests(section, existing, ingredients) or false
  if action == "remove_zero" and not cleared then
    return
  end
  local message
  if target.type == "item" then
    message = action == "remove_zero"
        and {
          "quidquid.action-item-temporary-request-removed",
          item_caption(target, quality),
          target_prototype(target).localised_name,
        }
      or {
        "quidquid.action-item-temporary-request-already-satisfied",
        item_caption(target, quality),
        target_prototype(target).localised_name,
      }
  else
    if quality_system_active() then
      message = action == "remove_zero"
          and {
            "quidquid.action-recipe-temporary-request-removed",
            recipe_caption(target, quality),
            target_prototype(target).localised_name,
            ingredient_caption(ingredients),
          }
        or {
          "quidquid.action-recipe-temporary-request-already-satisfied",
          recipe_caption(target, quality),
          target_prototype(target).localised_name,
          quantity,
          ingredient_caption(ingredients),
        }
    else
      message = action == "remove_zero"
          and {
            "quidquid.action-recipe-temporary-request-removed",
            recipe_caption(target, quality),
            target_prototype(target).localised_name,
            ingredient_caption(ingredients),
          }
        or {
          "quidquid.action-recipe-temporary-request-already-satisfied",
          recipe_caption(target, quality),
          target_prototype(target).localised_name,
          quantity,
          ingredient_caption(ingredients),
        }
    end
  end
  player.create_local_flying_text({ text = message, create_at_cursor = true })
end

--- Dispatches a click inside the editor: a quality button, the +/- buttons, or Confirm.
---
--- A quality button is identified by its tag rather than its name, since one exists per
--- unlocked quality; the others by name.
---@param event table  on_gui_click; event.element's name and tags are what select the
---  branch
function TemporaryRequestEditor.on_gui_click(event)
  local element = event.element
  if element == nil or not element.valid then
    return
  end
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end
  if element.tags.quidquid_quality ~= nil then
    select_quality(player, element.tags.quidquid_quality)
  elseif element.name == MINUS_BUTTON_NAME or element.name == PLUS_BUTTON_NAME then
    local content = content_of(player)
    if content == nil then
      return
    end
    local target = target_from_content(content)
    local textfield = quantity_row_of(content)[TEXTFIELD_NAME]
    local current = parse_quantity(textfield.text) or 0
    local next_quantity
    if target.type == "recipe" then
      next_quantity = element.name == PLUS_BUTTON_NAME and TemporaryRequestEditorLogic.next_quantity(current)
        or TemporaryRequestEditorLogic.previous_quantity(current)
    else
      local stack_size = prototypes.item[target.name].stack_size
      next_quantity = element.name == PLUS_BUTTON_NAME
          and TemporaryRequestEditorLogic.next_stack_multiple(current, stack_size)
        or TemporaryRequestEditorLogic.previous_stack_multiple(current, stack_size)
    end
    set_quantity_controls(content, next_quantity)
  elseif element.name == CONFIRM_BUTTON_NAME then
    TemporaryRequestEditor.confirm(player)
  end
end

--- Re-evaluates the entered quantity as the player types, updating the error
--- background and Confirm's enabled state.
---@param event table  on_gui_text_changed; ignored unless it is the editor's textfield
function TemporaryRequestEditor.on_gui_text_changed(event)
  local element = event.element
  if element == nil or not element.valid or element.name ~= TEXTFIELD_NAME then
    return
  end
  local player = game.get_player(event.player_index)
  local content = player ~= nil and content_of(player) or nil
  if content ~= nil then
    refresh_quantity_validity(content)
  end
end

--- Destroys the frame when Factorio closes it, e.g. on Escape or when another GUI
--- takes over `player.opened`.
---@param event table  on_gui_closed; ignored unless it is this editor's frame
function TemporaryRequestEditor.on_gui_closed(event)
  if event.element == nil or not event.element.valid or event.element.name ~= FRAME_NAME then
    return
  end
  local player = game.get_player(event.player_index)
  if player ~= nil then
    TemporaryRequestEditor.close(player)
  end
end

--- Confirms on the keyboard shortcut, so Enter works without clicking Confirm.
---@param event table  the custom-input event
function TemporaryRequestEditor.on_confirm_key(event)
  local player = game.get_player(event.player_index)
  if player ~= nil then
    TemporaryRequestEditor.confirm(player)
  end
end

--- Closes the editor from its titlebar close button.
---
--- Identified by tag rather than name: the button is built from the same helper the
--- palette's own close button uses.
---@param event table  on_gui_click; ignored unless the element carries the cancel tag
function TemporaryRequestEditor.on_cancel_button(event)
  local element = event.element
  if element == nil or not element.valid or element.tags.quidquid_temporary_request_editor_cancel == nil then
    return
  end
  local player = game.get_player(event.player_index)
  if player ~= nil then
    TemporaryRequestEditor.close(player)
  end
end

return TemporaryRequestEditor
