local FactorySearchAction = require("lib.actions.factory_search_action")

describe("FactorySearchAction", function()
  after_each(function()
    _G.prototypes = nil
  end)

  describe(".resolve_signal", function()
    it("passes an item through", function()
      assert.are.same(
        { type = "item", name = "iron-plate" },
        FactorySearchAction.resolve_signal({ type = "item", id = "iron-plate" })
      )
    end)

    it("passes a fluid through", function()
      assert.are.same(
        { type = "fluid", name = "water" },
        FactorySearchAction.resolve_signal({ type = "fluid", id = "water" })
      )
    end)

    it("maps a recipe to its main product", function()
      _G.prototypes = {
        recipe = {
          ["advanced-oil-processing"] = {
            main_product = { type = "fluid", name = "petroleum-gas" },
            products = {
              { type = "fluid", name = "heavy-oil" },
              { type = "fluid", name = "light-oil" },
              { type = "fluid", name = "petroleum-gas" },
            },
          },
        },
      }

      assert.are.same(
        { type = "fluid", name = "petroleum-gas" },
        FactorySearchAction.resolve_signal({ type = "recipe", id = "advanced-oil-processing" })
      )
    end)

    it("maps a recipe without a main product to its only product", function()
      _G.prototypes = {
        recipe = { ["iron-gear-wheel"] = { products = { { type = "item", name = "iron-gear-wheel" } } } },
      }

      assert.are.same(
        { type = "item", name = "iron-gear-wheel" },
        FactorySearchAction.resolve_signal({ type = "recipe", id = "iron-gear-wheel" })
      )
    end)

    it("returns nil for a recipe with several products and no main product", function()
      _G.prototypes = {
        recipe = {
          ["uranium-processing"] = {
            products = { { type = "item", name = "uranium-235" }, { type = "item", name = "uranium-238" } },
          },
        },
      }

      assert.is_nil(FactorySearchAction.resolve_signal({ type = "recipe", id = "uranium-processing" }))
    end)

    it("returns nil for a recipe whose product is neither an item nor a fluid", function()
      _G.prototypes = {
        recipe = { research = { products = { { type = "research-progress", name = "research" } } } },
      }

      assert.is_nil(FactorySearchAction.resolve_signal({ type = "recipe", id = "research" }))
    end)

    it("returns nil for a recipe that no longer exists", function()
      _G.prototypes = { recipe = {} }

      assert.is_nil(FactorySearchAction.resolve_signal({ type = "recipe", id = "gone" }))
    end)

    it("maps a resource to its first mineable product", function()
      _G.prototypes = {
        entity = {
          ["iron-ore"] = { mineable_properties = { products = { { type = "item", name = "iron-ore" } } } },
        },
      }

      assert.are.same(
        { type = "item", name = "iron-ore" },
        FactorySearchAction.resolve_signal({ type = "resource", id = "1", resource_name = "iron-ore" })
      )
    end)

    it("returns nil for a resource without mineable products", function()
      _G.prototypes = { entity = { ["odd-rock"] = { mineable_properties = {} } } }

      assert.is_nil(FactorySearchAction.resolve_signal({ type = "resource", id = "1", resource_name = "odd-rock" }))
    end)

    it("returns nil for a resource whose entity prototype no longer exists", function()
      _G.prototypes = { entity = {} }

      assert.is_nil(FactorySearchAction.resolve_signal({ type = "resource", id = "1", resource_name = "gone" }))
    end)
  end)

  describe(".interface_ready", function()
    local function stub_caller(functions, version)
      return {
        has = function(_, interface_name, function_name)
          return interface_name == "factory-search" and functions[function_name] == true
        end,
        call = function(_, interface_name, function_name)
          assert.are.equal("factory-search", interface_name)
          assert.are.equal("interop_version", function_name)
          return version
        end,
      }
    end

    it("is false without the interface", function()
      assert.is_false(FactorySearchAction.interface_ready(stub_caller({}, 1)))
    end)

    it("is false when interop_version is missing", function()
      assert.is_false(FactorySearchAction.interface_ready(stub_caller({ search = true }, 1)))
    end)

    it("is false for another interop version", function()
      assert.is_false(FactorySearchAction.interface_ready(stub_caller({ search = true, interop_version = true }, 2)))
    end)

    it("is true for interop version 1", function()
      assert.is_true(FactorySearchAction.interface_ready(stub_caller({ search = true, interop_version = true }, 1)))
    end)
  end)
end)
