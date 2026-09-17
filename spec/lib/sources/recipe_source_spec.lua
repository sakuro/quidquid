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

      assert.are.equal(1, #candidates)
      assert.are.equal("recipe", candidates[1].type)
      assert.are.equal("iron-gear-wheel", candidates[1].id)
      assert.are.same({ "recipe-name.iron-gear-wheel" }, candidates[1].label)
      assert.are.equal("recipe/iron-gear-wheel", candidates[1].icon)
      assert.is_number(candidates[1].search_score)
    end)
  end)
end)
