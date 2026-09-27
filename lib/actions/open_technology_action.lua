local OpenTechnologyAction = {}

local function execute(selected_candidate, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return
  end
  if prototypes.technology[selected_candidate.id] == nil then
    log(("quidquid: open-technology could not resolve prototype '%s'"):format(tostring(selected_candidate.id)))
    return
  end
  player.open_technology_gui(selected_candidate.id)
end

--- Adds this action's remote interface, named by its declaration in prototypes/actions.lua.
function OpenTechnologyAction.add_interface()
  remote.add_interface("quidquid.open-technology-action", { execute = execute })
end

return OpenTechnologyAction
