local RecipeSource = require("lib.sources.recipe_source")

local function fake_translation_cache(entries)
  entries = entries or {}
  return {
    get = function(_, locale, internal_name)
      local by_locale = entries[locale]
      if by_locale == nil then
        return nil
      end
      return by_locale[internal_name]
    end,
  }
end

describe("RecipeSource", function()
  describe(".build_candidates", function()
    it("builds recipe candidates with recipe icons", function()
      local recipes = {
        { name = "iron-gear-wheel", localised_name = { "recipe-name.iron-gear-wheel" }, hidden = false },
      }

      local candidates = RecipeSource.build_candidates("iron", recipes, "en", fake_translation_cache(), false)

      assert.are.same({
        {
          type = "recipe",
          id = "iron-gear-wheel",
          label = { "recipe-name.iron-gear-wheel" },
          icon = "recipe/iron-gear-wheel",
        },
      }, candidates)
    end)
  end)
end)
