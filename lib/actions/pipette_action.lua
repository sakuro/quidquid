local PipetteAction = {}

-- allow_ghost = true so this always offers a ghost when the player has none of the
-- item, regardless of the "pick ghost item if no items are available" interface
-- setting -- that setting isn't exposed to mods, so this is the only way to
-- guarantee the behavior rather than depend on the player's own client config.
local function execute(selected_candidate, _params, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return
  end
  local prototype = prototypes.item[selected_candidate.id]
  if prototype == nil then
    return
  end
  player.pipette(prototype, nil, true)
end

function PipetteAction.register()
  remote.add_interface("quidquid.pipette-action", { execute = execute })
  remote.call("quidquid", "register_action", {
    version = 1,
    id = "pipette",
    types = { "item" },
    label = { "controls.pipette" },
    key = "quidquid-pipette",
    interface = "quidquid.pipette-action",
  })
end

return PipetteAction
