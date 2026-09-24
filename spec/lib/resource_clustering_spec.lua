local ResourceClustering = require("lib.resource_clustering")

describe("ResourceClustering", function()
  describe(".chunk_key", function()
    it("joins the coordinates with a comma", function()
      assert.are.equal("3,-2", ResourceClustering.chunk_key(3, -2))
    end)
  end)

  describe(".neighbour_keys", function()
    it("returns the eight surrounding chunks and not the chunk itself", function()
      local keys = ResourceClustering.neighbour_keys("0,0")

      table.sort(keys)
      assert.are.same({ "-1,-1", "-1,0", "-1,1", "0,-1", "0,1", "1,-1", "1,0", "1,1" }, keys)
    end)
  end)

  describe(".group_chunk", function()
    it("sums amount and tile count per resource name", function()
      local grouped = ResourceClustering.group_chunk({
        { name = "iron-ore", amount = 100, position = { x = 1, y = 1 } },
        { name = "iron-ore", amount = 250, position = { x = 2, y = 1 } },
        { name = "copper-ore", amount = 40, position = { x = 3, y = 3 } },
      })

      assert.are.equal(350, grouped["iron-ore"].amount)
      assert.are.equal(2, grouped["iron-ore"].tiles)
      assert.are.equal(40, grouped["copper-ore"].amount)
      assert.are.equal(1, grouped["copper-ore"].tiles)
    end)

    it("bounds each resource by its own entity positions", function()
      local grouped = ResourceClustering.group_chunk({
        { name = "crude-oil", amount = 3000, position = { x = -5, y = 12 } },
        { name = "crude-oil", amount = 9000, position = { x = 20, y = -4 } },
      })

      assert.are.same({ left = -5, top = -4, right = 20, bottom = 12 }, {
        left = grouped["crude-oil"].left,
        top = grouped["crude-oil"].top,
        right = grouped["crude-oil"].right,
        bottom = grouped["crude-oil"].bottom,
      })
    end)

    it("returns an empty table for a chunk with no resources", function()
      assert.are.same({}, ResourceClustering.group_chunk({}))
    end)
  end)
end)
