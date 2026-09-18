local OpenFactoriopediaAction = require("lib.actions.open_factoriopedia_action")
local SurfaceAccess = require("lib.surface_access")

describe("OpenFactoriopediaAction", function()
  local original_resolve = SurfaceAccess.resolve
  local original_planet_prototype = SurfaceAccess.planet_prototype

  after_each(function()
    _G.prototypes = nil
    SurfaceAccess.resolve = original_resolve
    SurfaceAccess.planet_prototype = original_planet_prototype
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

    it("resolves the space-platform prototype for a platform surface", function()
      _G.prototypes = { surface = { ["space-platform"] = "space-platform-prototype" } }
      SurfaceAccess.resolve = function(_candidate, _player)
        return { platform = {} }
      end

      assert.are.equal(
        "space-platform-prototype",
        OpenFactoriopediaAction.resolve_prototype({ type = "surface", id = 1 }, {})
      )
    end)

    it("resolves a generated planet's prototype from the real surface", function()
      SurfaceAccess.resolve = function(_candidate, _player)
        return { planet = { prototype = "nauvis-prototype" } }
      end

      assert.are.equal("nauvis-prototype", OpenFactoriopediaAction.resolve_prototype({ type = "surface", id = 1 }, {}))
    end)

    it("falls back to the planet prototype when the planet has no generated surface yet", function()
      SurfaceAccess.resolve = function(_candidate, _player)
        return nil
      end
      SurfaceAccess.planet_prototype = function(_candidate)
        return "vulcanus-prototype"
      end

      assert.are.equal(
        "vulcanus-prototype",
        OpenFactoriopediaAction.resolve_prototype({ type = "surface", planet_name = "vulcanus" }, {})
      )
    end)

    it("returns nil for an unresolvable surface candidate", function()
      SurfaceAccess.resolve = function(_candidate, _player)
        return nil
      end
      SurfaceAccess.planet_prototype = function(_candidate)
        return nil
      end

      assert.is_nil(OpenFactoriopediaAction.resolve_prototype({ type = "surface", id = 1 }, {}))
    end)

    it("returns nil for an unknown candidate type", function()
      assert.is_nil(OpenFactoriopediaAction.resolve_prototype({ type = "technology", id = "automation" }, {}))
    end)
  end)
end)
