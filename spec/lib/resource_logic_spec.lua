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
  describe(".secondary_text", function()
    it("returns the plain string when occupied is false", function()
      local text = ResourceLogic.secondary_text("[planet=nauvis]", { x = -137.5, y = -330.1 }, false)

      assert.are.equal("[planet=nauvis] (-138, -331)", text)
    end)

    it("returns the plain string when occupied is omitted", function()
      local text = ResourceLogic.secondary_text("[planet=nauvis]", { x = -137, y = -330 })

      assert.are.equal("[planet=nauvis] (-137, -330)", text)
    end)

    it(
      "returns a LocalisedString carrying the token, the floored coordinates, the occupied key and the "
        .. "plain second line's own font wrapper, when occupied is true",
      function()
        local text = ResourceLogic.secondary_text("[planet=nauvis]", { x = -137.5, y = -330.1 }, true)

        -- lib/search_highlight.lua's highlight(value, nil, "default", "default-bold") --
        -- what Palette.internal_caption calls for a plain secondary_text -- wraps a
        -- plain string as "[font=default]" .. value .. "[/font]" when there are no
        -- ranges to bold. A non-string value skips that wrapper entirely (highlight
        -- returns it unchanged), so this LocalisedString must carry the identical
        -- "[font=default]"/"[/font]" tags itself, or an occupied row's second line
        -- would render in a different font from every other row's.
        assert.are.same(
          { "", "[font=default]", "[planet=nauvis] (-138, -331) ", { "quidquid.resource-occupied" }, "[/font]" },
          text
        )
      end
    )
  end)

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
      -- candidates[1] is the 9000-amount cluster (richest first); NumberFormat.suffixed
      -- renders that as "9.0k".
      assert.are.equal("Iron ore 9.0k", candidates[1].search_display_name)
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

    it("labels a candidate with the translated name and the amount when a translation is available", function()
      local candidates = ResourceLogic.build_candidates("copper", clusters, "en", translated, localised_names)

      -- The copper-ore fixture's amount is 100, under the "k" tier, so
      -- NumberFormat.suffixed renders it as the plain whole number "100".
      assert.are.equal("Copper ore 100", candidates[1].label)
    end)

    it("falls back to the localised name, with the amount appended, when untranslated", function()
      local candidates = ResourceLogic.build_candidates("copper", clusters, "en", {}, localised_names)

      assert.are.same({ "", { "entity-name.copper-ore" }, " ", "100" }, candidates[1].label)
    end)

    it("sets both label and search_display_name to the same plain string when translated", function()
      local candidates = ResourceLogic.build_candidates("copper", clusters, "en", translated, localised_names)

      assert.are.equal("Copper ore 100", candidates[1].label)
      assert.are.equal("Copper ore 100", candidates[1].search_display_name)
    end)

    it("leaves search_display_name nil when untranslated, even though label still carries the amount", function()
      local candidates = ResourceLogic.build_candidates("copper", clusters, "en", {}, localised_names)

      assert.is_nil(candidates[1].search_display_name)
      assert.are.same({ "", { "entity-name.copper-ore" }, " ", "100" }, candidates[1].label)
    end)

    it("keeps search_display_ranges inside the name, not spilling into the appended amount", function()
      local candidates = ResourceLogic.build_candidates("copper", clusters, "en", translated, localised_names)

      -- "Copper ore" is 10 bytes; the amount is appended after it, so every matched
      -- range must stay within those first 10 bytes for the highlight to still land
      -- on the name after the append.
      local name_length = #"Copper ore"
      assert.is_true(#candidates[1].search_display_ranges > 0)
      for _, range in ipairs(candidates[1].search_display_ranges) do
        assert.is_true(range.end_byte <= name_length)
      end
    end)

    it("sorts by the numeric amount, not the formatted amount string", function()
      -- 9000 formats as "9.0k" and 800 as "800"; comparing amount as a number must
      -- still put the 9000 cluster first, whatever the formatted text happens to say.
      local unformatted_order_clusters = {
        cluster("iron-ore:small", "iron-ore", 800, { left = 0, top = 0, right = 10, bottom = 10 }, {
          ["0,0"] = { amount = 800, left = 0, top = 0, right = 10, bottom = 10, anchor = { x = 5, y = 5 } },
        }),
        cluster("iron-ore:large", "iron-ore", 9000, { left = 100, top = 100, right = 110, bottom = 110 }, {
          ["10,10"] = {
            amount = 9000,
            left = 100,
            top = 100,
            right = 110,
            bottom = 110,
            anchor = { x = 105, y = 105 },
          },
        }),
      }

      local candidates =
        ResourceLogic.build_candidates("iron", unformatted_order_clusters, "en", translated, localised_names)

      assert.are.equal("iron-ore:large", candidates[1].id)
      assert.are.equal("iron-ore:small", candidates[2].id)
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

    it("builds a candidate with a plain-string secondary_text and no annotation", function()
      -- The occupied marker used to be a right-end `annotation` set by the runtime
      -- resource_source.lua, applied after build_candidates ran. That field is gone
      -- now: build_candidates itself never sets it, occupied or not -- occupancy is a
      -- runtime fact this pure module has no way to know at candidate-build time.
      local surface_tokens = { [1] = "[planet=nauvis]" }
      local candidates =
        ResourceLogic.build_candidates("copper", clusters, "en", translated, localised_names, surface_tokens)

      assert.are.equal("[planet=nauvis] (-5, -5)", candidates[1].secondary_text)
      assert.is_nil(candidates[1].annotation)
    end)

    it("carries the surface token on the candidate, for the runtime source to recompose secondary_text with", function()
      -- lib/sources/resource_source.lua rewrites secondary_text when a patch turns out
      -- to be occupied (a runtime fact this pure module never learns), and needs the
      -- same surface token this function used to build the plain second line.
      -- Carrying it as its own field keeps that a plain field read, not a parse of
      -- secondary_text's rendered text.
      local surface_tokens = { [1] = "[planet=nauvis]" }
      local candidates =
        ResourceLogic.build_candidates("copper", clusters, "en", translated, localised_names, surface_tokens)

      assert.are.equal("[planet=nauvis]", candidates[1].surface_token)
    end)

    it("falls back to the surface index as surface_token when the surface has no token in the map", function()
      local candidates = ResourceLogic.build_candidates("copper", clusters, "en", translated, localised_names, {})

      assert.are.equal("1", candidates[1].surface_token)
    end)
  end)
end)
