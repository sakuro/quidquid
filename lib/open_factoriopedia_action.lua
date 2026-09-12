-- lib/open_factoriopedia_action.lua
local OpenFactoriopediaAction = {}

local PROTOTYPE_TABLES_BY_TYPE = {
  item = prototypes.item,
}

local function execute(selected_candidate, _params, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return
  end
  local prototype_table = PROTOTYPE_TABLES_BY_TYPE[selected_candidate.type]
  if prototype_table == nil then
    return
  end
  local prototype = prototype_table[selected_candidate.id]
  if prototype == nil then
    return
  end
  player.open_factoriopedia_gui(prototype)
end

function OpenFactoriopediaAction.register()
  remote.add_interface("quidquid.open-factoriopedia-action", { execute = execute })
  remote.call("quidquid", "register_action", {
    version = 1,
    id = "open-factoriopedia",
    types = {"item"},
    label = {"quidquid.action-open-factoriopedia"},
    key = "confirm",
    interface = "quidquid.open-factoriopedia-action",
  })
end

return OpenFactoriopediaAction
