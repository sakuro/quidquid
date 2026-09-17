local flib_dictionary = require("__flib__.dictionary")
local build_candidates = require("lib.sources.prototype_candidate")

local RecipeSource = {}

local SOURCE_LABEL = { "quidquid.source-recipes" }
local NAMESPACE = "recipes"

local function collect_recipes()
  local recipes = {}
  for _, recipe in pairs(prototypes.recipe) do
    table.insert(recipes, recipe)
  end
  return recipes
end

function RecipeSource.register_dictionary()
  flib_dictionary.new(NAMESPACE)
  for _, recipe in ipairs(collect_recipes()) do
    flib_dictionary.add(NAMESPACE, recipe.name, recipe.localised_name)
  end
end

function RecipeSource.build_candidates(query, recipes, locale, translated_names, include_hidden)
  return build_candidates("recipe", "recipe", query, recipes, locale, translated_names, include_hidden)
end

local function search(query, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return {}
  end
  local include_hidden = player.mod_settings["quidquid-include-hidden"].value
  local translated_names = flib_dictionary.get(player_index, NAMESPACE) or {}
  return RecipeSource.build_candidates(query, collect_recipes(), player.locale, translated_names, include_hidden)
end

function RecipeSource.register()
  remote.add_interface("quidquid.recipe-source", { search = search })
  remote.call("quidquid", "register_source", {
    version = 1,
    id = "recipes",
    type = "recipe",
    label = SOURCE_LABEL,
    prefixes = { "r", "recipe" },
    default_active = true,
    interface = "quidquid.recipe-source",
  })
end

return RecipeSource
