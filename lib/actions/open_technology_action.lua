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

--- Adds this action's remote interface and registers it with Quidquid.
---
--- Registered on the Factoriopedia input for technology candidates: the technology
--- screen is the more useful destination for a technology than its Factoriopedia page.
function OpenTechnologyAction.register()
  remote.add_interface("quidquid.open-technology-action", { execute = execute })
  remote.call("quidquid", "register_action", {
    contract_version = 1,
    id = "open-technology",
    types = { "technology" },
    label = { "quidquid.action-open-technology" },
    input_name = "quidquid-open-factoriopedia",
    interface = "quidquid.open-technology-action",
  })
end

return OpenTechnologyAction
