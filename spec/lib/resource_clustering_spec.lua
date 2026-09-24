local ResourceClustering = require("lib.resource_clustering")

local function entry(amount, x, y)
  return { amount = amount, tiles = 1, left = x, top = y, right = x, bottom = y }
end

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

  describe(".insert", function()
    it("creates a cluster for a chunk with no charted neighbour", function()
      local store = ResourceClustering.new_store()

      local cluster = ResourceClustering.insert(store, 1, "iron-ore", "0,0", entry(100, 5, 5))

      assert.are.equal("iron-ore:0,0", cluster.id)
      assert.are.equal(1, cluster.surface_index)
      assert.are.equal(100, cluster.amount)
      assert.are.equal(1, #ResourceClustering.all(store))
    end)

    it("merges a chunk into a cluster that owns a neighbouring chunk", function()
      local store = ResourceClustering.new_store()
      ResourceClustering.insert(store, 1, "iron-ore", "0,0", entry(100, 5, 5))

      local cluster = ResourceClustering.insert(store, 1, "iron-ore", "1,0", entry(50, 40, 5))

      assert.are.equal("iron-ore:0,0", cluster.id)
      assert.are.equal(150, cluster.amount)
      assert.are.same({ left = 5, top = 5, right = 40, bottom = 5 }, cluster.bounds)
      assert.are.equal(1, #ResourceClustering.all(store))
    end)

    it("keeps a different resource in the same chunk separate", function()
      local store = ResourceClustering.new_store()
      ResourceClustering.insert(store, 1, "iron-ore", "0,0", entry(100, 5, 5))

      ResourceClustering.insert(store, 1, "copper-ore", "0,0", entry(70, 6, 6))

      assert.are.equal(2, #ResourceClustering.all(store))
    end)

    it("joins two clusters when a chunk bridges them", function()
      local store = ResourceClustering.new_store()
      ResourceClustering.insert(store, 1, "iron-ore", "0,0", entry(100, 5, 5))
      ResourceClustering.insert(store, 1, "iron-ore", "2,0", entry(100, 70, 5))
      assert.are.equal(2, #ResourceClustering.all(store))

      local cluster = ResourceClustering.insert(store, 1, "iron-ore", "1,0", entry(10, 40, 5))

      assert.are.equal(1, #ResourceClustering.all(store))
      assert.are.equal(210, cluster.amount)
    end)

    it("replaces the entry when the same chunk is inserted twice", function()
      local store = ResourceClustering.new_store()
      ResourceClustering.insert(store, 1, "iron-ore", "0,0", entry(100, 5, 5))

      local cluster = ResourceClustering.insert(store, 1, "iron-ore", "0,0", entry(60, 5, 5))

      assert.are.equal(60, cluster.amount)
      assert.are.equal(1, #ResourceClustering.all(store))
    end)
  end)

  describe(".remove_chunk", function()
    it("drops the chunk and keeps the cluster", function()
      local store = ResourceClustering.new_store()
      ResourceClustering.insert(store, 1, "iron-ore", "0,0", entry(100, 5, 5))
      ResourceClustering.insert(store, 1, "iron-ore", "1,0", entry(50, 40, 5))

      assert.is_true(ResourceClustering.remove_chunk(store, "iron-ore", "1,0"))

      local clusters = ResourceClustering.all(store)
      assert.are.equal(1, #clusters)
      assert.are.equal(100, clusters[1].amount)
    end)

    it("removes the cluster once its last chunk is gone", function()
      local store = ResourceClustering.new_store()
      ResourceClustering.insert(store, 1, "iron-ore", "0,0", entry(100, 5, 5))

      ResourceClustering.remove_chunk(store, "iron-ore", "0,0")

      assert.are.same({}, ResourceClustering.all(store))
    end)

    it("keeps one cluster when the chunk between its halves is removed", function()
      local store = ResourceClustering.new_store()
      ResourceClustering.insert(store, 1, "iron-ore", "0,0", entry(100, 5, 5))
      ResourceClustering.insert(store, 1, "iron-ore", "1,0", entry(10, 40, 5))
      ResourceClustering.insert(store, 1, "iron-ore", "2,0", entry(100, 70, 5))

      ResourceClustering.remove_chunk(store, "iron-ore", "1,0")

      local clusters = ResourceClustering.all(store)
      assert.are.equal(1, #clusters)
      assert.are.equal(200, clusters[1].amount)
    end)

    it("reports nothing removed for a chunk it does not hold", function()
      local store = ResourceClustering.new_store()

      assert.is_false(ResourceClustering.remove_chunk(store, "iron-ore", "9,9"))
    end)
  end)

  describe(".subtract", function()
    it("lowers the chunk's amount and the cluster's total", function()
      local store = ResourceClustering.new_store()
      ResourceClustering.insert(store, 1, "iron-ore", "0,0", entry(100, 5, 5))

      assert.is_true(ResourceClustering.subtract(store, "iron-ore", "0,0", 30))

      assert.are.equal(70, ResourceClustering.all(store)[1].amount)
    end)

    it("drops a chunk subtracted to nothing, and the cluster with it", function()
      local store = ResourceClustering.new_store()
      ResourceClustering.insert(store, 1, "iron-ore", "0,0", entry(100, 5, 5))

      ResourceClustering.subtract(store, "iron-ore", "0,0", 100)

      assert.are.same({}, ResourceClustering.all(store))
    end)

    it("reports nothing subtracted for a chunk it does not hold", function()
      local store = ResourceClustering.new_store()

      assert.is_false(ResourceClustering.subtract(store, "iron-ore", "9,9", 10))
    end)
  end)
end)
