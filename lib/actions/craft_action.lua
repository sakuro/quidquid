local CraftAction = {}

local function resolve_recipe(player, selected_candidate)
  return player.force.recipes[selected_candidate.id]
end

function CraftAction.is_applicable(selected_candidate, player_index)
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

function CraftAction.count_of(n)
  return function(_player, _recipe)
    return n
  end
end

function CraftAction.max_craftable(player, recipe)
  return math.max(1, player.get_craftable_count(recipe))
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
    player.begin_crafting{count = count_for(player, recipe), recipe = recipe}
  end
end

local function register(id, key, interface, label, count_for)
  remote.add_interface(interface, {
    is_applicable = CraftAction.is_applicable,
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
  register("craft-1", "quidquid-confirm", "quidquid.craft-1-action", {"quidquid.action-craft-1"}, CraftAction.count_of(1))
  register("craft-5", "quidquid-craft-5", "quidquid.craft-5-action", {"quidquid.action-craft-5"}, CraftAction.count_of(5))
  register("craft-all", "quidquid-craft-all", "quidquid.craft-all-action", {"quidquid.action-craft-all"}, CraftAction.max_craftable)
end

return CraftAction
