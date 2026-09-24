local LogisticsState = {}

--- Classifies why a player can or cannot make a personal logistics request.
---
--- - no_character: no player.character to request from at all (god mode, editor, ...)
--- - locked: force.character_logistic_requests is off. Confirmed over RCON (Factorio
---   2.1.19) that in this state character.get_logistic_point(character_requester)
---   returns nil even while standing inside a roboport's range -- so a nil
---   requester_point alone can't tell "locked" apart from "no_character", which is
---   why has_character comes in separately.
--- - out_of_range: requests are enabled and the point exists, but outside any
---   logistic network's range. Confirmed over RCON that logistic_network is then not
---   nil but an object with valid == false -- check valid, not nil.
--- - connected: inside a network's range.
---@param has_character boolean
---@param requester_point LuaLogisticPoint|nil  only `logistic_network` is read;
---  extracted by the caller, e.g. TemporaryRequestAction.requester_point_for
---@return string  "no_character", "locked", "out_of_range" or "connected"
function LogisticsState.classify(has_character, requester_point)
  if not has_character then
    return "no_character"
  end
  if requester_point == nil then
    return "locked"
  end
  local network = requester_point.logistic_network
  if network == nil or not network.valid then
    return "out_of_range"
  end
  return "connected"
end

return LogisticsState
