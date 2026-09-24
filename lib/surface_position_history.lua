local History = {}

--- Records where a player was on a surface, so remote view can return them there.
---
--- The position is copied field by field rather than stored by reference: the caller
--- passes a live MapPosition the runtime is free to reuse.
---@param history table  the stored history table, mutated in place
---@param player_index uint
---@param surface_index uint
---@param position MapPosition
function History.remember(history, player_index, surface_index, position)
  history[player_index] = history[player_index] or {}
  history[player_index][surface_index] = { x = position.x, y = position.y }
end

--- The remembered position for one player on one surface.
---@param history table
---@param player_index uint
---@param surface_index uint
---@param fallback MapPosition|nil  returned when nothing is remembered yet
---@return MapPosition|nil
function History.get(history, player_index, surface_index, fallback)
  local positions = history[player_index]
  return positions and positions[surface_index] or fallback
end

--- Forgets one surface for every player, for when that surface is deleted.
---
--- Surface indices are reused, so a leftover entry would send a player to a position
--- remembered for a different surface.
---@param history table  mutated in place
---@param surface_index uint
function History.remove_surface(history, surface_index)
  for _, positions in pairs(history) do
    positions[surface_index] = nil
  end
end

return History
