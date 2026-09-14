local SurfaceAccess = require("lib.surface_access")
local History = require("lib.surface_position_history")

local OpenRemoteViewAction = {}

local function history()
  storage.surface_positions = storage.surface_positions or {}
  return storage.surface_positions
end

local function remember(player)
  History.remember(history(), player.index, player.surface.index, player.position)
end

function OpenRemoteViewAction.on_player_changed_position(event)
  local player = game.get_player(event.player_index)
  if player ~= nil then remember(player) end
end

function OpenRemoteViewAction.on_pre_surface_deleted(event)
  History.remove_surface(history(), event.surface_index)
end

function OpenRemoteViewAction.on_player_removed(event)
  history()[event.player_index] = nil
end

local function is_applicable(candidate, player_index)
  local player = game.get_player(player_index)
  return player ~= nil and SurfaceAccess.resolve_remote_view(candidate, player) ~= nil
end

local function execute(candidate, _params, player_index)
  local player = game.get_player(player_index)
  if player == nil then return end
  local surface = SurfaceAccess.resolve_remote_view(candidate, player)
  if surface == nil then return end
  remember(player)
  local platform = surface.platform
  local fallback = platform and platform.hub and platform.hub.position
    or player.force.get_spawn_position(surface)
  local position = History.get(history(), player.index, surface.index, fallback)
  player.set_controller{type = defines.controllers.remote, surface = surface, position = position}
  remember(player)
end

function OpenRemoteViewAction.register()
  remote.add_interface("quidquid.open-remote-view-action", {
    is_applicable = is_applicable, execute = execute,
  })
  remote.call("quidquid", "register_action", {
    version = 1, id = "open-remote-view", types = {"surface"},
    label = {"quidquid.action-open-remote-view"}, key = "quidquid-confirm",
    interface = "quidquid.open-remote-view-action",
  })
end

return OpenRemoteViewAction
