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

-- A resource candidate opens at the patch's own coordinates: the position is
-- exactly what makes a patch worth finding, so it never falls back to something
-- remembered. A surface candidate opens where the player last stood on that
-- surface, since a surface has no patch-like "there" of its own.
local function resolve(candidate, player)
  if candidate.type == "resource" then
    local surface = game.get_surface(candidate.surface_index)
    if surface == nil then
      return nil, "quidquid.action-open-remote-view-unavailable"
    end
    return { surface = surface, position = candidate.position }, nil
  end

  local surface, locale_key = SurfaceAccess.resolve_remote_view(candidate, player)
  if surface == nil then
    return nil, locale_key
  end
  -- Recorded before the read below so a jump back onto the surface the player is
  -- already remote-viewing lands on them: without this, the read would return
  -- whatever was remembered before this visit (stale, or the platform/spawn
  -- fallback), throwing the camera somewhere the player is not currently standing.
  remember(player)
  local platform = surface.platform
  local fallback = platform and platform.hub and platform.hub.position or player.force.get_spawn_position(surface)
  return { surface = surface, position = History.get(history(), player.index, surface.index, fallback) }, nil
end

-- is_available only gates by candidate type (via this action's registered `types`);
-- whether remote view actually works for this specific surface (generated, unlocked
-- -- see README "Surfaces") is a per-candidate runtime fact, so it's resolved here
-- and reported by execute, not hidden from the tooltip.
local function execute(candidate, player_index)
  ActionRunner.run(candidate, player_index, resolve, function(target, _candidate, player)
    remember(player)
    player.set_controller({ type = defines.controllers.remote, surface = target.surface, position = target.position })
    -- Recorded again after landing, at the jump's own destination -- for a resource
    -- candidate that means the patch's coordinates, not anywhere the player has
    -- actually stood. That's intentional: a later plain surface jump back to this
    -- surface should pick up from here, not from wherever the player was before.
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
    types = { "surface", "resource" },
    label = { "quidquid.action-open-remote-view" },
    input_name = "quidquid-open-remote-view",
    interface = "quidquid.open-remote-view-action",
  })
end

return OpenRemoteViewAction
