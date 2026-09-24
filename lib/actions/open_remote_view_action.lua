local ActionRunner = require("lib.action_runner")
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

--- Remembers where the player is, so remote view can return them there later.
---
--- Tracked continuously rather than only when the action runs: by the time a player
--- opens remote view onto another surface, they have already left the position worth
--- returning to. Registered from control.lua.
---@param event table  on_player_changed_position
function OpenRemoteViewAction.on_player_changed_position(event)
  local player = game.get_player(event.player_index)
  if player ~= nil then
    remember(player)
  end
end

--- Forgets a deleted surface's remembered positions, for every player.
---
--- Surface indices are reused, so a leftover entry would place a player at a position
--- remembered for a different surface. Registered from control.lua.
---@param event table  on_pre_surface_deleted
function OpenRemoteViewAction.on_pre_surface_deleted(event)
  History.remove_surface(history(), event.surface_index)
end

--- Forgets a removed player's remembered positions. Registered from control.lua.
---@param event table  on_player_removed
function OpenRemoteViewAction.on_player_removed(event)
  history()[event.player_index] = nil
end

-- is_available only gates by candidate type (via this action's registered `types`);
-- whether remote view actually works for this specific surface (generated, unlocked
-- -- see README "Surfaces") is a per-candidate runtime fact, so it's resolved here
-- and reported by execute, not hidden from the tooltip.
local function execute(candidate, player_index)
  ActionRunner.run(candidate, player_index, SurfaceAccess.resolve_remote_view, function(surface, _candidate, player)
    remember(player)
    local platform = surface.platform
    local fallback = platform and platform.hub and platform.hub.position or player.force.get_spawn_position(surface)
    local position = History.get(history(), player.index, surface.index, fallback)
    player.set_controller({ type = defines.controllers.remote, surface = surface, position = position })
    remember(player)
  end, "quidquid.action-open-remote-view-unavailable")
end

--- Adds this action's remote interface and registers it with Quidquid.
---
--- The event handlers above are registered separately, from control.lua: they have to
--- run whether or not the palette is ever opened.
function OpenRemoteViewAction.register()
  remote.add_interface("quidquid.open-remote-view-action", { execute = execute })
  remote.call("quidquid", "register_action", {
    contract_version = 1,
    id = "open-remote-view",
    types = { "surface" },
    label = { "quidquid.action-open-remote-view" },
    input_name = "quidquid-open-remote-view",
    interface = "quidquid.open-remote-view-action",
  })
end

return OpenRemoteViewAction
