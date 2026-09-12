-- lib/actions/craft_action.lua
local CraftAction = {}

local function resolve_recipe(player, selected_candidate)
  return player.force.recipes[selected_candidate.id]
end

local function is_applicable(selected_candidate, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return false
  end
  local recipe = resolve_recipe(player, selected_candidate)
  if recipe == nil then
    return false
  end
  return not player.force.get_hand_crafting_disabled_for_recipe(recipe)
end

local function report_failure(player, recipe)
  if player.force.get_hand_crafting_disabled_for_recipe(recipe) then
    player.create_local_flying_text{text = {"recipe-not-craftable-in-hand"}, create_at_cursor = true}
  else
    player.create_local_flying_text{text = {"not-enough-ingredients"}, create_at_cursor = true}
  end
end

local function count_of(n)
  return function(_player, _recipe)
    return n
  end
end

local function max_craftable(player, recipe)
  return player.get_craftable_count(recipe)
end

local function craft(count_for)
  return function(selected_candidate, _params, player_index)
    local player = game.get_player(player_index)
    if player == nil then
      return
    end
    local recipe = resolve_recipe(player, selected_candidate)
    if recipe == nil then
      return
    end
    local requested = count_for(player, recipe)
    if requested == 0 then
      report_failure(player, recipe)
      return
    end
    local started = player.begin_crafting{count = requested, recipe = recipe}
    if started == 0 then
      report_failure(player, recipe)
    end
  end
end

local function register(id, key, interface, label, count_for)
  remote.add_interface(interface, {
    is_applicable = is_applicable,
    execute = craft(count_for),
  })
  remote.call("quidquid", "register_action", {
    version = 1,
    id = id,
    types = {"item"},
    label = label,
    key = key,
    interface = interface,
  })
end

function CraftAction.register()
  register("craft-1", "quidquid-confirm", "quidquid.craft-1-action", {"quidquid.action-craft-1"}, count_of(1))
  register("craft-5", "quidquid-craft-5", "quidquid.craft-5-action", {"quidquid.action-craft-5"}, count_of(5))
  register("craft-max", "quidquid-craft-max", "quidquid.craft-max-action", {"quidquid.action-craft-max"}, max_craftable)
end

return CraftAction
