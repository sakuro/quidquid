local flib_dictionary = require("__flib__.dictionary")
local build_candidates = require("lib.sources.prototype_candidate")

local RecipeSource = {}

local NAMESPACE = "recipes"

local function collect_recipes()
  local recipes = {}
  for _, recipe in pairs(prototypes.recipe) do
    table.insert(recipes, recipe)
  end
  return recipes
end

--- Registers the recipe-name dictionary with flib, for translated-name search.
---
--- Must run from on_init/on_configuration_changed, before the first on_tick (see
--- control.lua and EXTENDING.md "Translated names").
function RecipeSource.register_dictionary()
  flib_dictionary.new(NAMESPACE)
  for _, recipe in ipairs(collect_recipes()) do
    flib_dictionary.add(NAMESPACE, recipe.name, recipe.localised_name)
  end
end

--- Builds this source's candidates for one query.
---@param query string
---@param recipes table  array of recipe prototypes
---@param translated_names table  prototype name -> translated name
---@param include_hidden boolean
---@return table  candidates; see EXTENDING.md "Candidates"
function RecipeSource.build_candidates(query, recipes, translated_names, include_hidden)
  return build_candidates("recipe", "recipe", query, recipes, translated_names, include_hidden)
end

local function search(query, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return {}
  end
  local include_hidden = player.mod_settings["quidquid-include-hidden"].value
  local translated_names = flib_dictionary.get(player_index, NAMESPACE) or {}
  return RecipeSource.build_candidates(query, collect_recipes(), translated_names, include_hidden)
end

--- Adds this source's remote interface, named by its declaration in prototypes/sources.lua.
function RecipeSource.add_interface()
  remote.add_interface("quidquid.recipe-source", { search = search })
end

return RecipeSource
