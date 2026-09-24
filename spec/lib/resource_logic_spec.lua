local ResourceLogic = require("lib.resource_logic")

local function cluster(id, resource_name, amount, bounds)
  return {
    id = id,
    surface_index = 1,
    resource_name = resource_name,
    chunks = {},
    amount = amount,
    bounds = bounds,
  }
end

describe("ResourceLogic", function()
  describe(".build_candidates", function()
    local clusters = {
      cluster("iron-ore:0,0", "iron-ore", 5000, { left = 0, top = 0, right = 40, bottom = 20 }),
      cluster("iron-ore:9,9", "iron-ore", 9000, { left = 300, top = 300, right = 310, bottom = 310 }),
      cluster("copper-ore:0,0", "copper-ore", 100, { left = -10, top = -10, right = 0, bottom = 0 }),
    }
    local translated = { ["iron-ore"] = "Iron ore", ["copper-ore"] = "Copper ore" }

    it("matches on the translated name", function()
      local candidates = ResourceLogic.build_candidates("iron", clusters, "en", translated)

      assert.are.equal(2, #candidates)
      assert.are.equal("resource", candidates[1].type)
      assert.are.equal("Iron ore", candidates[1].search_display_name)
    end)

    it("matches on the prototype name", function()
      local candidates = ResourceLogic.build_candidates("copper-ore", clusters, "en", translated)

      assert.are.equal(1, #candidates)
      assert.are.equal("copper-ore:0,0", candidates[1].id)
    end)

    it("orders same-named clusters by descending amount", function()
      local candidates = ResourceLogic.build_candidates("iron", clusters, "en", translated)

      assert.are.equal("iron-ore:9,9", candidates[1].id)
      assert.are.equal("iron-ore:0,0", candidates[2].id)
    end)

    it("puts the centre of the bounds on the candidate", function()
      local candidates = ResourceLogic.build_candidates("copper", clusters, "en", translated)

      assert.are.same({ x = -5, y = -5 }, candidates[1].position)
    end)

    it("names the resource's entity sprite as the icon", function()
      local candidates = ResourceLogic.build_candidates("copper", clusters, "en", translated)

      assert.are.equal("entity/copper-ore", candidates[1].icon)
    end)

    it("returns nothing when no cluster matches", function()
      assert.are.same({}, ResourceLogic.build_candidates("uranium", clusters, "en", translated))
    end)
  end)
end)
