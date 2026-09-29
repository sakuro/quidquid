local DefaultSearch = {}

-- Quidquid's own sources are in the default search by fixed rule, not by a
-- setting: an extension's membership is the player's choice, these are part of
-- what Quidquid is. The calculator stays prefix-only.
DefaultSearch.ALWAYS = {
  ["quidquid-items"] = true,
  ["quidquid-fluids"] = true,
  ["quidquid-recipes"] = true,
  ["quidquid-technologies"] = true,
}

--- The per-player setting that puts an extension's source in the default search.
---@param id string  the source's declaration name
---@return string
function DefaultSearch.setting_name(id)
  return id .. "-default-search"
end

--- Whether the running mod settings support a source's default-search setting.
---
--- "ok" for a runtime-per-user bool setting of that name, "invalid" for any other
--- setting of that name, nil when there is none.
---@param name string
---@return string|nil
local function classify(name)
  local setting = prototypes.mod_setting[name]
  if setting == nil then
    return nil
  end
  if setting.type == "bool-setting" and setting.setting_type == "runtime-per-user" then
    return "ok"
  end
  return "invalid"
end

--- The player's value of a setting classify returned "ok" for.
---@param player_index uint
---@param name string
---@return boolean
local function enabled(player_index, name)
  local player = game.get_player(player_index)
  return player ~= nil and player.mod_settings[name].value == true
end

--- Lookups against the running game, the default for Registry.new.
DefaultSearch.runtime = {
  classify = classify,
  enabled = enabled,
}

return DefaultSearch
