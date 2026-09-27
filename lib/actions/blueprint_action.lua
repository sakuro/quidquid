local ActionRunner = require("lib.action_runner")
local BlueprintLogic = require("lib.blueprint_logic")

local BlueprintAction = {}

local UNAVAILABLE = "quidquid.action-blueprint-unavailable"

-- Injected from control.lua (see BlueprintAction.init) rather than required directly,
-- the same arrangement TemporaryRequestAction.init uses for its editor: this module
-- stays loadable without the GUI one.
local export_window = nil

local function resolve(candidate, player)
  local location, indices = BlueprintLogic.parse_id(candidate.id)
  if location == nil then
    return nil, UNAVAILABLE
  end
  if location == "inv" then
    local inventory = player.get_main_inventory()
    local stack = inventory ~= nil
        and BlueprintLogic.resolve_item(
          inventory,
          indices,
          defines.inventory.item_main,
          candidate.record_type,
          candidate.label
        )
      or nil
    if stack == nil then
      return nil, UNAVAILABLE
    end
    return { stack = stack, inventory = inventory, slot = #indices == 1 and indices[1] or nil }, nil
  end
  local roots = location == "my" and player.blueprints or game.blueprints
  local record = BlueprintLogic.resolve(roots, indices, candidate.record_type, candidate.label)
  if record == nil then
    return nil, UNAVAILABLE
  end
  return { record = record }, nil
end

local function export_string(target)
  if target.record ~= nil then
    return target.record.export_record()
  end
  return target.stack.export_stack()
end

local function flying_text(player, locale_key, candidate)
  player.create_local_flying_text({
    text = { locale_key, "[img=" .. candidate.icon .. "]", candidate.label },
    create_at_cursor = true,
  })
end

-- A library record cannot itself go in the cursor (cursor_record is read-only), so
-- holding one gives an imported copy, which clearing the cursor leaves in the
-- inventory. An inventory item is moved into the cursor itself, as clicking its slot
-- would; hand_location then sends it back to that slot on Q. An item taken out of a
-- book item has no slot of its own to return to, so it gets no hand location.
local function hold(candidate, player_index)
  ActionRunner.run(candidate, player_index, resolve, function(target, selected_candidate, player)
    if player.cursor_stack == nil or not player.clear_cursor() then
      flying_text(player, "quidquid.action-blueprint-cursor-busy", selected_candidate)
      return
    end
    if target.stack ~= nil then
      -- clear_cursor() can insert the cursor's former contents into this same main
      -- inventory and shift slots, so the target resolved before it may no longer be
      -- the right stack; resolve again against the post-clear inventory.
      local fresh_target = resolve(selected_candidate, player)
      if fresh_target == nil then
        flying_text(player, UNAVAILABLE, selected_candidate)
        return
      end
      if not player.cursor_stack.swap_stack(fresh_target.stack) then
        flying_text(player, "quidquid.action-blueprint-hold-failed", selected_candidate)
        return
      end
      if fresh_target.slot ~= nil then
        player.hand_location = { inventory = fresh_target.inventory.index, slot = fresh_target.slot }
      end
      flying_text(player, "quidquid.action-blueprint-held", selected_candidate)
      return
    end
    if player.cursor_stack.import_stack(export_string(target)) == -1 then
      player.cursor_stack.clear()
      flying_text(player, "quidquid.action-blueprint-import-failed", selected_candidate)
    else
      flying_text(player, "quidquid.action-blueprint-held", selected_candidate)
    end
  end)
end

local function copy_to_inventory(candidate, player_index)
  ActionRunner.run(candidate, player_index, resolve, function(target, selected_candidate, player)
    local inventory = player.get_main_inventory()
    if inventory == nil then
      flying_text(player, "quidquid.action-blueprint-no-inventory", selected_candidate)
      return
    end
    local stack = inventory.find_empty_stack()
    if stack == nil then
      flying_text(player, "quidquid.action-blueprint-inventory-full", selected_candidate)
      return
    end
    if stack.import_stack(export_string(target)) == -1 then
      stack.clear()
      flying_text(player, "quidquid.action-blueprint-import-failed", selected_candidate)
    else
      flying_text(player, "quidquid.action-blueprint-copied", selected_candidate)
    end
  end)
end

--- Hands in the export window module.
---
--- Injected rather than required so this module stays loadable without the GUI one,
--- the same arrangement TemporaryRequestAction.init uses for its editor.
---@param window table  lib/blueprint_export_window.lua
function BlueprintAction.init(window)
  export_window = window
end

local function export(candidate, player_index)
  ActionRunner.run(candidate, player_index, resolve, function(target, _selected_candidate, player)
    export_window.open(player, export_string(target))
  end)
end

local function register(id, input_name, interface, execute)
  remote.add_interface(interface, { execute = execute })
  remote.call("quidquid", "register_action", {
    contract_version = 1,
    id = id,
    types = { "blueprint" },
    label = { "quidquid.action-" .. id },
    input_name = input_name,
    interface = interface,
  })
end

--- Adds the blueprint actions' remote interfaces and registers them with Quidquid.
function BlueprintAction.register()
  register("hold-blueprint", "quidquid-hold-blueprint", "quidquid.hold-blueprint-action", hold)
  register("copy-blueprint", "quidquid-copy-blueprint", "quidquid.copy-blueprint-action", copy_to_inventory)
  register("export-blueprint", "quidquid-export-blueprint", "quidquid.export-blueprint-action", export)
end

return BlueprintAction
