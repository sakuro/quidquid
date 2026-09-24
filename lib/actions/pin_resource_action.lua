local ActionRunner = require("lib.action_runner")

local PinResourceAction = {}

local PREVIEW_DISTANCE = 64

local function resolve(candidate, _player)
  local surface = game.get_surface(candidate.surface_index)
  if surface == nil then
    return nil, "quidquid.action-pin-resource-unavailable"
  end
  return surface, nil
end

-- is_available only gates by candidate type (via this action's registered `types`);
-- whether the patch's surface still exists is a per-candidate runtime fact, so it's
-- resolved here and reported by execute, not hidden from the tooltip.
--
-- resource = selected_candidate.resource_name passes a prototype name string, one of
-- the three forms runtime-api.json's EntityID union accepts for LuaPlayer.add_pin's
-- resource parameter; its description ("The resource prototype to add an entire
-- resource patch with") confirms this pins the whole patch rather than one entity.
local function execute(candidate, player_index)
  ActionRunner.run(candidate, player_index, resolve, function(surface, selected_candidate, player)
    player.add_pin({
      surface = surface,
      position = selected_candidate.position,
      resource = selected_candidate.resource_name,
      label = selected_candidate.label,
      preview_distance = PREVIEW_DISTANCE,
    })
  end, "quidquid.action-pin-resource-unavailable")
end

--- Adds this action's remote interface and registers it with Quidquid.
function PinResourceAction.register()
  remote.add_interface("quidquid.pin-resource-action", { execute = execute })
  remote.call("quidquid", "register_action", {
    contract_version = 1,
    id = "pin-resource",
    types = { "resource" },
    label = { "quidquid.action-pin-resource" },
    input_name = "quidquid-pin-resource",
    interface = "quidquid.pin-resource-action",
  })
end

return PinResourceAction
