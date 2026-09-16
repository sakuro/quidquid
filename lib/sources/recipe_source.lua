local TranslatedPrototypeSource = require("lib.sources.translated_prototype_source")
local build_candidates = require("lib.sources.prototype_candidate")

local RecipeSource = {}

local SOURCE_LABEL = { "quidquid.source-recipes" }

local function collect_recipes()
  local recipes = {}
  for _, recipe in pairs(prototypes.recipe) do
    table.insert(recipes, recipe)
  end
  return recipes
end

local translation = TranslatedPrototypeSource.new("recipes", collect_recipes, SOURCE_LABEL)

function RecipeSource.build_candidates(query, recipes, locale, translation_cache, include_hidden)
  return build_candidates("recipe", "recipe", query, recipes, locale, translation_cache, include_hidden)
end

function RecipeSource.on_string_translated(event)
  translation:on_string_translated(event)
end

function RecipeSource.on_player_joined_game(event)
  translation:on_player_joined_game(event)
end

RecipeSource.on_player_locale_changed = RecipeSource.on_player_joined_game

function RecipeSource.on_player_left_game(event)
  translation:on_player_left_game(event)
end

function RecipeSource.on_init()
  translation:on_init()
end

function RecipeSource.on_configuration_changed()
  translation:on_configuration_changed()
end

local function search(query, player_index, _context)
  local player = game.get_player(player_index)
  if player == nil then
    return {}
  end
  local include_hidden = player.mod_settings["quidquid-include-hidden"].value
  return RecipeSource.build_candidates(query, collect_recipes(), player.locale, translation, include_hidden)
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
