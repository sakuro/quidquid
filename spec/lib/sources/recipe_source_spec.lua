local RecipeSource = require("lib.sources.recipe_source")

describe("RecipeSource", function()
  describe(".build_candidates", function()
    it("builds recipe candidates with recipe icons", function()
      local recipes = {
        { name = "iron-gear-wheel", localised_name = { "recipe-name.iron-gear-wheel" }, hidden = false },
      }

      local candidates = RecipeSource.build_candidates("iron", recipes, "en", {}, false)

      assert.are.equal(1, #candidates)
      assert.are.equal("recipe", candidates[1].type)
      assert.are.equal("iron-gear-wheel", candidates[1].id)
      assert.are.same({ "recipe-name.iron-gear-wheel" }, candidates[1].label)
      assert.are.equal("recipe/iron-gear-wheel", candidates[1].icon)
      assert.is_number(candidates[1].search_score)
    end)
  end)
end)
