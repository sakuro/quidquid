local ItemSource = require("lib.sources.item_source")

describe("ItemSource", function()
  describe(".build_candidates", function()
    it("delegates to prototype_candidate with the item type and icon prefix", function()
      local items = {
        { name = "iron-plate", localised_name = { "item-name.iron-plate" }, hidden = false },
      }

      local candidates = ItemSource.build_candidates("iron", items, "en", {}, false)

      assert.are.equal(1, #candidates)
      assert.are.equal("item", candidates[1].type)
      assert.are.equal("iron-plate", candidates[1].id)
      assert.are.same({ "item-name.iron-plate" }, candidates[1].label)
      assert.are.equal("item/iron-plate", candidates[1].icon)
      assert.is_number(candidates[1].search_score)
    end)
  end)

  describe(".format_count", function()
    it("renders a non-zero count plainly", function()
      assert.are.equal("45", ItemSource.format_count(45))
    end)

    it("colors a zero count muted so it doesn't compete with what the player holds", function()
      assert.are.equal("[color=160,160,160]0[/color]", ItemSource.format_count(0))
    end)
  end)

  describe(".build_caption", function()
    it("shows only the inventory count when locked", function()
      assert.are.equal("12", ItemSource.build_caption("locked", 12, 340))
    end)

    it("shows the network as an em dash when out of range", function()
      assert.are.equal("12 · —", ItemSource.build_caption("out_of_range", 12, 340))
    end)

    it("shows both counts when connected", function()
      assert.are.equal("12 · 340", ItemSource.build_caption("connected", 12, 340))
    end)
  end)

  describe(".build_tooltip", function()
    it("shows only the inventory line when locked", function()
      local tooltip = ItemSource.build_tooltip("locked", 12, { { quality = "normal", count = 12 } })

      assert.are.same({ "", { "quidquid.item-counts-inventory", "12" } }, tooltip)
    end)

    it("adds core's not-in-logistic-network line when out of range", function()
      local tooltip = ItemSource.build_tooltip("out_of_range", 12, { { quality = "normal", count = 12 } })

      assert.are.same({
        "",
        { "quidquid.item-counts-inventory", "12" },
        "\n",
        { "gui.not-in-logistic-network" },
      }, tooltip)
    end)

    it("adds a numeric network line when connected", function()
      local tooltip = ItemSource.build_tooltip(
        "connected",
        12,
        { { quality = "normal", count = 12 } },
        340,
        { { quality = "normal", count = 340 } }
      )

      assert.are.same({
        "",
        { "quidquid.item-counts-inventory", "12" },
        "\n",
        { "quidquid.item-counts-network", "340" },
      }, tooltip)
    end)

    it("appends a per-quality breakdown to a line when more than one quality is present", function()
      local tooltip = ItemSource.build_tooltip("locked", 45, {
        { quality = "legendary", count = 5 },
        { quality = "normal", count = 40 },
      })

      assert.are.same({
        "",
        {
          "",
          { "quidquid.item-counts-inventory", "45" },
          " (",
          { "", "[quality=legendary]5, [quality=normal]40" },
          ")",
        },
      }, tooltip)
    end)

    it("omits the breakdown when only one quality is present", function()
      local tooltip = ItemSource.build_tooltip("locked", 12, { { quality = "normal", count = 12 } })

      assert.are.same({ "", { "quidquid.item-counts-inventory", "12" } }, tooltip)
    end)

    it("adds a delivering line when robots are carrying some to the player", function()
      local tooltip = ItemSource.build_tooltip(
        "connected",
        12,
        { { quality = "normal", count = 12 } },
        340,
        { { quality = "normal", count = 340 } },
        5
      )

      assert.are.same({
        "",
        { "quidquid.item-counts-inventory", "12" },
        "\n",
        { "quidquid.item-counts-network", "340" },
        "\n",
        { "quidquid.item-counts-delivering", "5" },
      }, tooltip)
    end)

    it("omits the delivering line when nothing is being delivered", function()
      local tooltip = ItemSource.build_tooltip(
        "connected",
        12,
        { { quality = "normal", count = 12 } },
        340,
        { { quality = "normal", count = 340 } },
        0
      )

      assert.are.same({
        "",
        { "quidquid.item-counts-inventory", "12" },
        "\n",
        { "quidquid.item-counts-network", "340" },
      }, tooltip)
    end)

    it("adds a picking-up line when robots are carrying some away from the player", function()
      local tooltip = ItemSource.build_tooltip(
        "connected",
        12,
        { { quality = "normal", count = 12 } },
        340,
        { { quality = "normal", count = 340 } },
        0,
        3
      )

      assert.are.same({
        "",
        { "quidquid.item-counts-inventory", "12" },
        "\n",
        { "quidquid.item-counts-network", "340" },
        "\n",
        { "quidquid.item-counts-picking-up", "3" },
      }, tooltip)
    end)

    it("never shows delivering/picking-up lines outside the connected state", function()
      local tooltip =
        ItemSource.build_tooltip("out_of_range", 12, { { quality = "normal", count = 12 } }, nil, nil, 5, 3)

      assert.are.same({
        "",
        { "quidquid.item-counts-inventory", "12" },
        "\n",
        { "gui.not-in-logistic-network" },
      }, tooltip)
    end)
  end)

  describe(".build_annotation", function()
    it("returns nil when the player has no character", function()
      assert.is_nil(ItemSource.build_annotation("no_character", 12, {}, 340, {}))
    end)

    it("combines the caption and tooltip when locked", function()
      local annotation = ItemSource.build_annotation("locked", 12, { { quality = "normal", count = 12 } }, 0, {})

      assert.are.equal("12", annotation.caption)
      assert.are.same({ "", { "quidquid.item-counts-inventory", "12" } }, annotation.tooltip)
    end)
  end)
end)
