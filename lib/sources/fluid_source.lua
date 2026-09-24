local flib_dictionary = require("__flib__.dictionary")
local build_candidates = require("lib.sources.prototype_candidate")

local FluidSource = {}

local SOURCE_LABEL = { "quidquid.source-fluids" }
local NAMESPACE = "fluids"

local function collect_fluids()
  local fluids = {}
  for _, fluid in pairs(prototypes.fluid) do
    table.insert(fluids, fluid)
  end
  return fluids
end

--- Registers the fluid-name dictionary with flib, for translated-name search.
---
--- Must run from on_init/on_configuration_changed, before the first on_tick -- see
--- control.lua and EXTENDING.md "Translated names".
function FluidSource.register_dictionary()
  flib_dictionary.new(NAMESPACE)
  for _, fluid in ipairs(collect_fluids()) do
    flib_dictionary.add(NAMESPACE, fluid.name, fluid.localised_name)
  end
end

--- Builds this source's candidates for one query.
---@param query string
---@param fluids table  array of fluid prototypes
---@param locale string|nil
---@param translated_names table  prototype name -> translated name
---@param include_hidden boolean
---@return table  candidates; see EXTENDING.md "Candidates"
function FluidSource.build_candidates(query, fluids, locale, translated_names, include_hidden)
  return build_candidates("fluid", "fluid", query, fluids, locale, translated_names, include_hidden)
end

local function search(query, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return {}
  end
  local include_hidden = player.mod_settings["quidquid-include-hidden"].value
  local translated_names = flib_dictionary.get(player_index, NAMESPACE) or {}
  return FluidSource.build_candidates(query, collect_fluids(), player.locale, translated_names, include_hidden)
end

--- Adds this source's remote interface and registers it with Quidquid.
function FluidSource.register()
  remote.add_interface("quidquid.fluid-source", { search = search })
  remote.call("quidquid", "register_source", {
    contract_version = 1,
    id = "fluids",
    type = "fluid",
    label = SOURCE_LABEL,
    prefixes = { "f", "fluid" },
    in_default_search = true,
    interface = "quidquid.fluid-source",
  })
end

return FluidSource
