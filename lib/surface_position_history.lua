local History = {}

function History.remember(history, player_index, surface_index, position)
  history[player_index] = history[player_index] or {}
  history[player_index][surface_index] = {x = position.x, y = position.y}
end

function History.get(history, player_index, surface_index, fallback)
  local positions = history[player_index]
  return positions and positions[surface_index] or fallback
end

function History.remove_surface(history, surface_index)
  for _, positions in pairs(history) do positions[surface_index] = nil end
end

return History
