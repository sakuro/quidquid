local OpenTechnologyAction = {}

local function execute(selected_candidate, _params, player_index)
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

function OpenTechnologyAction.register()
  remote.add_interface("quidquid.open-technology-action", { execute = execute })
  remote.call("quidquid", "register_action", {
    version = 1,
    id = "open-technology",
    types = { "technology" },
    label = { "quidquid.action-open-technology" },
    key = "quidquid-open-factoriopedia",
    interface = "quidquid.open-technology-action",
  })
end

return OpenTechnologyAction
