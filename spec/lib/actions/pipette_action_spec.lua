local PipetteAction = require("lib.actions.pipette_action")

describe("PipetteAction", function()
  before_each(function()
    _G.prototypes = { item = { ["iron-plate"] = "iron-plate-prototype" } }
  end)

  after_each(function()
    _G.prototypes = nil
  end)

  describe(".resolve_item_prototype", function()
    it("resolves the sole item product", function()
      local recipe = { products = { { type = "item", name = "iron-plate" } } }

      assert.are.equal("iron-plate-prototype", PipetteAction.resolve_item_prototype(recipe))
    end)

    it("returns nil for a sole fluid product", function()
      local recipe = { products = { { type = "fluid", name = "water" } } }

      assert.is_nil(PipetteAction.resolve_item_prototype(recipe))
    end)

    it("resolves the item main_product when there are several products", function()
      local recipe = {
        products = {
          { type = "item", name = "uranium-235" },
          { type = "item", name = "iron-plate" },
        },
        main_product = { type = "item", name = "iron-plate" },
      }

      assert.are.equal("iron-plate-prototype", PipetteAction.resolve_item_prototype(recipe))
    end)

    it("returns nil when several products have no declared main_product", function()
      local recipe = {
        products = {
          { type = "item", name = "uranium-235" },
          { type = "item", name = "uranium-238" },
        },
        main_product = nil,
      }

      assert.is_nil(PipetteAction.resolve_item_prototype(recipe))
    end)

    it("returns nil when a single-product recipe opts out via an empty main_product", function()
      local recipe = {
        products = {
          { type = "item", name = "uranium-235" },
          { type = "item", name = "uranium-238" },
        },
        main_product = "",
      }

      assert.is_nil(PipetteAction.resolve_item_prototype(recipe))
    end)

    it("returns nil when the main_product is a fluid", function()
      local recipe = {
        products = {
          { type = "item", name = "uranium-235" },
          { type = "fluid", name = "sulfuric-acid" },
        },
        main_product = { type = "fluid", name = "sulfuric-acid" },
      }

      assert.is_nil(PipetteAction.resolve_item_prototype(recipe))
    end)
  end)
end)
