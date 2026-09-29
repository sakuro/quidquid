local OpenFactoriopediaAction = require("lib.actions.open_factoriopedia_action")

describe("OpenFactoriopediaAction", function()
  after_each(function()
    _G.prototypes = nil
  end)

  describe(".resolve_prototype", function()
    it("resolves an item prototype", function()
      _G.prototypes = { item = { ["iron-plate"] = "iron-plate-prototype" } }

      assert.are.equal(
        "iron-plate-prototype",
        OpenFactoriopediaAction.resolve_prototype({ type = "item", id = "iron-plate" }, {})
      )
    end)

    it("resolves a fluid prototype", function()
      _G.prototypes = { fluid = { water = "water-prototype" } }

      assert.are.equal(
        "water-prototype",
        OpenFactoriopediaAction.resolve_prototype({ type = "fluid", id = "water" }, {})
      )
    end)

    it("resolves a recipe prototype", function()
      _G.prototypes = { recipe = { ["iron-plate"] = "iron-plate-recipe-prototype" } }

      assert.are.equal(
        "iron-plate-recipe-prototype",
        OpenFactoriopediaAction.resolve_prototype({ type = "recipe", id = "iron-plate" }, {})
      )
    end)

    it("returns nil for an unknown candidate type", function()
      assert.is_nil(OpenFactoriopediaAction.resolve_prototype({ type = "technology", id = "automation" }, {}))
    end)
  end)
end)
