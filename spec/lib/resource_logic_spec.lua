local ResourceLogic = require("lib.resource_logic")

local function cluster(id, resource_name, amount, bounds, chunks)
  return {
    id = id,
    surface_index = 1,
    resource_name = resource_name,
    chunks = chunks or {},
    amount = amount,
    bounds = bounds,
  }
end

describe("ResourceLogic", function()
  describe(".build_candidates", function()
    -- Each fixture cluster carries a real chunks table, not just bounds: position is
    -- now anchored on the richest chunk's own centre (Fix 3), and for a single-chunk
    -- cluster that chunk's bounds are set equal to the cluster's bounds so the two
    -- definitions coincide.
    local clusters = {
      cluster("iron-ore:0,0", "iron-ore", 5000, { left = 0, top = 0, right = 40, bottom = 20 }, {
        ["0,0"] = { amount = 5000, left = 0, top = 0, right = 40, bottom = 20 },
      }),
      cluster("iron-ore:9,9", "iron-ore", 9000, { left = 300, top = 300, right = 310, bottom = 310 }, {
        ["9,9"] = { amount = 9000, left = 300, top = 300, right = 310, bottom = 310 },
      }),
      cluster("copper-ore:0,0", "copper-ore", 100, { left = -10, top = -10, right = 0, bottom = 0 }, {
        ["0,0"] = { amount = 100, left = -10, top = -10, right = 0, bottom = 0 },
      }),
    }
    local translated = { ["iron-ore"] = "Iron ore", ["copper-ore"] = "Copper ore" }
    local localised_names = {
      ["iron-ore"] = { "entity-name.iron-ore" },
      ["copper-ore"] = { "entity-name.copper-ore" },
    }

    it("matches on the translated name", function()
      local candidates = ResourceLogic.build_candidates("iron", clusters, "en", translated, localised_names)

      assert.are.equal(2, #candidates)
      assert.are.equal("resource", candidates[1].type)
      assert.are.equal("Iron ore", candidates[1].search_display_name)
    end)

    it("matches on the prototype name", function()
      local candidates = ResourceLogic.build_candidates("copper-ore", clusters, "en", translated, localised_names)

      assert.are.equal(1, #candidates)
      assert.are.equal("copper-ore:0,0", candidates[1].id)
    end)

    it("orders same-named clusters by descending amount", function()
      local candidates = ResourceLogic.build_candidates("iron", clusters, "en", translated, localised_names)

      assert.are.equal("iron-ore:9,9", candidates[1].id)
      assert.are.equal("iron-ore:0,0", candidates[2].id)
    end)

    it("puts the centre of the richest chunk on a single-chunk cluster", function()
      local candidates = ResourceLogic.build_candidates("copper", clusters, "en", translated, localised_names)

      assert.are.same({ x = -5, y = -5 }, candidates[1].position)
    end)

    it("anchors position on the richest chunk's centre, not the bounding box's", function()
      local multi_chunk_clusters = {
        cluster("iron-ore:multi", "iron-ore", 6000, { left = 0, top = 0, right = 340, bottom = 20 }, {
          ["0,0"] = { amount = 1000, left = 0, top = 0, right = 40, bottom = 20 },
          ["9,0"] = { amount = 5000, left = 300, top = 0, right = 340, bottom = 20 },
        }),
      }

      local candidates = ResourceLogic.build_candidates("iron", multi_chunk_clusters, "en", translated, localised_names)

      -- The richer chunk ("9,0", amount 5000) centres at (320, 10). The bounding box
      -- centres at (170, 10) -- off the ore entirely, which is exactly the bug Fix 3
      -- exists to avoid.
      assert.are.same({ x = 320, y = 10 }, candidates[1].position)
    end)

    it("breaks a tie between equally rich chunks by chunk key, ascending", function()
      local tied_clusters = {
        cluster("iron-ore:tie", "iron-ore", 2000, { left = 0, top = 0, right = 340, bottom = 20 }, {
          ["9,0"] = { amount = 1000, left = 300, top = 0, right = 340, bottom = 20 },
          ["0,0"] = { amount = 1000, left = 0, top = 0, right = 40, bottom = 20 },
        }),
      }

      local candidates = ResourceLogic.build_candidates("iron", tied_clusters, "en", translated, localised_names)

      assert.are.same({ x = 20, y = 10 }, candidates[1].position)
    end)

    it("names the resource's entity sprite as the icon", function()
      local candidates = ResourceLogic.build_candidates("copper", clusters, "en", translated, localised_names)

      assert.are.equal("entity/copper-ore", candidates[1].icon)
    end)

    it("labels a candidate with the translated name when one is available", function()
      local candidates = ResourceLogic.build_candidates("copper", clusters, "en", translated, localised_names)

      assert.are.equal("Copper ore", candidates[1].label)
    end)

    it("falls back to the resource's localised name when there is no translated name yet", function()
      local candidates = ResourceLogic.build_candidates("copper", clusters, "en", {}, localised_names)

      assert.are.same({ "entity-name.copper-ore" }, candidates[1].label)
    end)

    it("returns nothing when no cluster matches", function()
      assert.are.same({}, ResourceLogic.build_candidates("uranium", clusters, "en", translated, localised_names))
    end)
  end)
end)
