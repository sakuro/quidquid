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
    -- Each fixture cluster carries a real chunks table, not just bounds: position comes
    -- from the richest chunk's `anchor`, an actual entity position recorded by
    -- ResourceClustering.group_chunk -- never a computed centre. See lib/resource_logic.lua
    -- for why a computed centre can land on a tile boundary with no ore under it.
    local clusters = {
      cluster("iron-ore:0,0", "iron-ore", 5000, { left = 0, top = 0, right = 40, bottom = 20 }, {
        ["0,0"] = { amount = 5000, left = 0, top = 0, right = 40, bottom = 20, anchor = { x = 20, y = 10 } },
      }),
      cluster("iron-ore:9,9", "iron-ore", 9000, { left = 300, top = 300, right = 310, bottom = 310 }, {
        ["9,9"] = { amount = 9000, left = 300, top = 300, right = 310, bottom = 310, anchor = { x = 305, y = 305 } },
      }),
      cluster("copper-ore:0,0", "copper-ore", 100, { left = -10, top = -10, right = 0, bottom = 0 }, {
        ["0,0"] = { amount = 100, left = -10, top = -10, right = 0, bottom = 0, anchor = { x = -5, y = -5 } },
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

    it("puts the richest chunk's anchor on a single-chunk cluster", function()
      local candidates = ResourceLogic.build_candidates("copper", clusters, "en", translated, localised_names)

      assert.are.same({ x = -5, y = -5 }, candidates[1].position)
    end)

    it("anchors position on the richest chunk's anchor, not the bounding box's centre", function()
      local multi_chunk_clusters = {
        cluster("iron-ore:multi", "iron-ore", 6000, { left = 0, top = 0, right = 340, bottom = 20 }, {
          ["0,0"] = { amount = 1000, left = 0, top = 0, right = 40, bottom = 20, anchor = { x = 20, y = 10 } },
          ["9,0"] = { amount = 5000, left = 300, top = 0, right = 340, bottom = 20, anchor = { x = 320, y = 10 } },
        }),
      }

      local candidates = ResourceLogic.build_candidates("iron", multi_chunk_clusters, "en", translated, localised_names)

      -- The richer chunk ("9,0", amount 5000) anchors at (320, 10), an actual entity
      -- position. The bounding box centres at (170, 10) -- off the ore entirely, which
      -- is exactly the bug the anchor exists to avoid.
      assert.are.same({ x = 320, y = 10 }, candidates[1].position)
    end)

    it("uses the richest chunk's recorded entity position, not a midpoint that can fall on a tile boundary", function()
      -- Entities at tile centres x = 0.5 and x = 9.5 span an odd number of tiles: their
      -- midpoint is (0.5 + 9.5) / 2 = 5.0, a whole integer -- a tile BOUNDARY, inside no
      -- resource entity's collision box. This is the exact defect reported in the field
      -- (see lib/resource_logic.lua's comment). group_chunk's anchor is recorded from a
      -- real entity, so it is immune to this per-axis parity coin-flip.
      local parity_clusters = {
        cluster("iron-ore:parity", "iron-ore", 2000, { left = 0.5, top = 0.5, right = 9.5, bottom = 0.5 }, {
          ["0,0"] = { amount = 2000, left = 0.5, top = 0.5, right = 9.5, bottom = 0.5, anchor = { x = 9.5, y = 0.5 } },
        }),
      }

      local candidates = ResourceLogic.build_candidates("iron", parity_clusters, "en", translated, localised_names)

      assert.are.same({ x = 9.5, y = 0.5 }, candidates[1].position)
      assert.are_not.equal(5.0, candidates[1].position.x)
    end)

    it("breaks a tie between equally rich chunks by chunk key, ascending", function()
      local tied_clusters = {
        cluster("iron-ore:tie", "iron-ore", 2000, { left = 0, top = 0, right = 340, bottom = 20 }, {
          ["9,0"] = { amount = 1000, left = 300, top = 0, right = 340, bottom = 20, anchor = { x = 320, y = 10 } },
          ["0,0"] = { amount = 1000, left = 0, top = 0, right = 40, bottom = 20, anchor = { x = 20, y = 10 } },
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

    it("puts the surface token and the floored position on secondary_text", function()
      local surface_tokens = { [1] = "[planet=nauvis]" }
      local candidates =
        ResourceLogic.build_candidates("copper", clusters, "en", translated, localised_names, surface_tokens)

      -- The copper-ore fixture's anchor is { x = -5, y = -5 }, already whole numbers;
      -- see the floored-position case below for a fixture that actually exercises
      -- math.floor.
      assert.are.equal("[planet=nauvis] (-5, -5)", candidates[1].secondary_text)
    end)

    it("floors fractional coordinates on secondary_text", function()
      local fractional_clusters = {
        cluster("iron-ore:fractional", "iron-ore", 2000, { left = 0, top = 0, right = 10, bottom = 10 }, {
          ["0,0"] = { amount = 2000, left = 0, top = 0, right = 10, bottom = 10, anchor = { x = -137.5, y = 9.9 } },
        }),
      }
      local surface_tokens = { [1] = "[planet=nauvis]" }

      local candidates =
        ResourceLogic.build_candidates("iron", fractional_clusters, "en", translated, localised_names, surface_tokens)

      assert.are.equal("[planet=nauvis] (-138, 9)", candidates[1].secondary_text)
    end)

    it("does not set search_internal_name or search_internal_ranges on a resource candidate", function()
      local surface_tokens = { [1] = "[planet=nauvis]" }
      local candidates =
        ResourceLogic.build_candidates("copper", clusters, "en", translated, localised_names, surface_tokens)

      assert.is_nil(candidates[1].search_internal_name)
      assert.is_nil(candidates[1].search_internal_ranges)
    end)

    it("still matches on the prototype name once search_internal_name is no longer displayed", function()
      local surface_tokens = { [1] = "[planet=nauvis]" }
      local candidates =
        ResourceLogic.build_candidates("copper-ore", clusters, "en", translated, localised_names, surface_tokens)

      assert.are.equal(1, #candidates)
      assert.are.equal("copper-ore:0,0", candidates[1].id)
    end)

    it("falls back to a usable secondary_text when the surface has no token in the map", function()
      -- surface_tokens is deliberately empty: a caller that did not describe this
      -- cluster's surface (or omitted the map entirely) must not crash or render
      -- a literal "nil" on the second line.
      local candidates = ResourceLogic.build_candidates("copper", clusters, "en", translated, localised_names, {})

      assert.are.equal("1 (-5, -5)", candidates[1].secondary_text)
    end)
  end)
end)
