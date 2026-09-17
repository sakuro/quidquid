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

function FluidSource.register_dictionary()
  flib_dictionary.new(NAMESPACE)
  for _, fluid in ipairs(collect_fluids()) do
    flib_dictionary.add(NAMESPACE, fluid.name, fluid.localised_name)
  end
end

function FluidSource.build_candidates(query, fluids, locale, translated_names, include_hidden)
  return build_candidates("fluid", "fluid", query, fluids, locale, translated_names, include_hidden)
end

local function search(query, player_index, _context)
  local player = game.get_player(player_index)
  if player == nil then
    return {}
  end
  local include_hidden = player.mod_settings["quidquid-include-hidden"].value
  local translated_names = flib_dictionary.get(player_index, NAMESPACE) or {}
  return FluidSource.build_candidates(query, collect_fluids(), player.locale, translated_names, include_hidden)
end

function FluidSource.register()
  remote.add_interface("quidquid.fluid-source", { search = search })
  remote.call("quidquid", "register_source", {
    version = 1,
    id = "fluids",
    type = "fluid",
    label = SOURCE_LABEL,
    prefixes = { "f", "fluid" },
    default_active = true,
    interface = "quidquid.fluid-source",
  })
end

return FluidSource
