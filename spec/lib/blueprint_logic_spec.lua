local BlueprintLogic = require("lib.blueprint_logic")

local ITEM_MAIN = 1

local function record(fields)
  fields.valid = fields.valid ~= false
  return fields
end

local function stack(fields)
  fields.valid_for_read = fields.valid_for_read ~= false
  return fields
end

local function book_stack(label, inner)
  return stack({
    is_blueprint_book = true,
    name = "blueprint-book",
    label = label,
    preview_icons = {},
    blueprint_description = "",
    get_inventory = function(index)
      assert.are.equal(ITEM_MAIN, index)
      return inner
    end,
  })
end

describe("BlueprintLogic", function()
  describe(".sprite_path", function()
    it("treats a missing type as item", function()
      assert.are.equal("item/rail", BlueprintLogic.sprite_path({ name = "rail" }))
    end)

    it("maps virtual to virtual-signal", function()
      assert.are.equal(
        "virtual-signal/signal-input",
        BlueprintLogic.sprite_path({ type = "virtual", name = "signal-input" })
      )
    end)

    it("uses other types as they are", function()
      assert.are.equal("fluid/water", BlueprintLogic.sprite_path({ type = "fluid", name = "water" }))
      assert.are.equal(
        "space-location/nauvis",
        BlueprintLogic.sprite_path({ type = "space-location", name = "nauvis" })
      )
    end)

    it("returns nil for a signal without a name", function()
      assert.is_nil(BlueprintLogic.sprite_path({ type = "virtual" }))
      assert.is_nil(BlueprintLogic.sprite_path(nil))
    end)
  end)

  describe(".icon_caption", function()
    local function always_valid()
      return true
    end

    it("joins icons in index order as img tags", function()
      local icons = {
        { index = 2, signal = { type = "virtual", name = "shape-t" } },
        { index = 1, signal = { name = "rail" } },
      }

      assert.are.equal("[img=item/rail][img=virtual-signal/shape-t]", BlueprintLogic.icon_caption(icons, always_valid))
    end)

    it("replaces an invalid sprite with the missing icon", function()
      local icons = { { index = 1, signal = { name = "gone" } }, { index = 2, signal = { name = "rail" } } }
      local function valid(path)
        return path ~= "item/gone"
      end

      assert.are.equal("[img=utility/missing_icon][img=item/rail]", BlueprintLogic.icon_caption(icons, valid))
    end)

    it("returns nil when there are no icons", function()
      assert.is_nil(BlueprintLogic.icon_caption({}, always_valid))
      assert.is_nil(BlueprintLogic.icon_caption(nil, always_valid))
    end)
  end)

  describe("ids", function()
    it("round-trips location and indices", function()
      local id = BlueprintLogic.format_id("my", { 3, 5, 2 })

      assert.are.equal("my/3/5/2", id)
      local location, indices = BlueprintLogic.parse_id(id)
      assert.are.equal("my", location)
      assert.are.same({ 3, 5, 2 }, indices)
    end)

    it("accepts the inventory location", function()
      local location, indices = BlueprintLogic.parse_id("inv/12")

      assert.are.equal("inv", location)
      assert.are.same({ 12 }, indices)
    end)

    it("rejects an unknown location or malformed id", function()
      assert.is_nil(BlueprintLogic.parse_id("other/1"))
      assert.is_nil(BlueprintLogic.parse_id("game/"))
      assert.is_nil(BlueprintLogic.parse_id("game/1/x"))
      assert.is_nil(BlueprintLogic.parse_id("game/1//2"))
      assert.is_nil(BlueprintLogic.parse_id("inv/0"))
      assert.is_nil(BlueprintLogic.parse_id("game/1/0"))
      assert.is_nil(BlueprintLogic.parse_id("my/01"))
    end)
  end)

  describe(".abbreviate", function()
    it("keeps a leading icon tag", function()
      assert.are.equal("[item=rail]", BlueprintLogic.abbreviate("[item=rail]鉄道"))
    end)

    it("skips a leading color tag and takes the first character", function()
      assert.are.equal("赤", BlueprintLogic.abbreviate("[color=red]赤い本[/color]"))
    end)

    it("takes the first UTF-8 character of plain text", function()
      assert.are.equal("鉄", BlueprintLogic.abbreviate("鉄道"))
      assert.are.equal("M", BlueprintLogic.abbreviate("Mall"))
    end)

    it("returns an empty string when nothing remains", function()
      assert.are.equal("", BlueprintLogic.abbreviate("[color=red][/color]"))
    end)
  end)

  describe(".book_path", function()
    it("returns nil for no books", function()
      assert.is_nil(BlueprintLogic.book_path({}))
    end)

    it("shows a single book in full", function()
      local path = BlueprintLogic.book_path({ "Mall" })

      assert.are.equal("Mall", path.full)
      assert.are.equal("Mall", path.display)
      assert.are.equal(1, path.full_start)
      assert.are.equal(1, path.display_start)
    end)

    it("abbreviates every book but the nearest", function()
      local path = BlueprintLogic.book_path({ "[item=rail]鉄道", "Stations", "Inbound" })

      assert.are.equal("[item=rail]鉄道 › Stations › Inbound", path.full)
      assert.are.equal("[item=rail] › S › Inbound", path.display)
      assert.are.equal(#"[item=rail]鉄道 › Stations › " + 1, path.full_start)
      assert.are.equal(#"[item=rail] › S › " + 1, path.display_start)
    end)

    it("drops a book that abbreviates to nothing", function()
      local path = BlueprintLogic.book_path({ "[color=red][/color]", "Inbound" })

      assert.are.equal("Inbound", path.display)
    end)
  end)

  describe(".to_nodes", function()
    it("converts records, sorted by key, walking books", function()
      local records = {
        [2] = record({
          type = "blueprint",
          label = "b",
          preview_icons = {},
          default_icons = { "d" },
          blueprint_description = "",
        }),
        [1] = record({
          type = "blueprint-book",
          label = "book",
          preview_icons = { "p" },
          blueprint_description = "desc",
          is_preview = false,
          contents = {
            [4] = record({ type = "upgrade-planner", label = "u", preview_icons = {}, planner_description = "pd" }),
          },
        }),
      }

      local nodes = BlueprintLogic.to_nodes(records)

      assert.are.same({
        {
          key = 1,
          type = "blueprint-book",
          label = "book",
          icons = { "p" },
          description = "desc",
          children = {
            { key = 4, type = "upgrade-planner", label = "u", icons = {}, description = "pd" },
          },
        },
        { key = 2, type = "blueprint", label = "b", icons = { "d" }, description = "" },
      }, nodes)
    end)

    it("does not walk a preview book or read default icons of a preview blueprint", function()
      local records = {
        record({ type = "blueprint-book", label = "p", preview_icons = {}, is_preview = true }),
        record({ type = "blueprint", label = "q", preview_icons = {}, is_preview = true }),
      }

      local nodes = BlueprintLogic.to_nodes(records)

      assert.is_nil(nodes[1].children)
      assert.are.same({}, nodes[2].icons)
      assert.is_nil(nodes[2].description)
    end)

    it("skips invalid records", function()
      assert.are.same({}, BlueprintLogic.to_nodes({ record({ valid = false, type = "blueprint" }) }))
    end)
  end)

  describe(".item_kind", function()
    it("names each blueprint-like item with the record type vocabulary", function()
      assert.are.equal("blueprint", BlueprintLogic.item_kind({ is_blueprint = true }))
      assert.are.equal("blueprint-book", BlueprintLogic.item_kind({ is_blueprint_book = true }))
      assert.are.equal("deconstruction-planner", BlueprintLogic.item_kind({ is_deconstruction_item = true }))
      assert.are.equal("upgrade-planner", BlueprintLogic.item_kind({ is_upgrade_item = true }))
      assert.is_nil(BlueprintLogic.item_kind({}))
    end)
  end)

  describe(".item_nodes", function()
    it("converts blueprint-like items, walking book items and skipping everything else", function()
      local inner = {
        stack({ valid_for_read = false }),
        stack({
          is_upgrade_item = true,
          name = "upgrade-planner",
          label = "u",
          preview_icons = {},
          planner_description = "",
        }),
      }
      local inventory = {
        stack({
          is_blueprint = true,
          name = "mod-blueprint",
          label = "a",
          preview_icons = {},
          default_icons = { "d" },
          blueprint_description = "x",
        }),
        stack({ name = "iron-plate" }),
        stack({ valid_for_read = false }),
        book_stack("b", inner),
      }

      assert.are.same({
        { key = 1, type = "blueprint", item_name = "mod-blueprint", label = "a", icons = { "d" }, description = "x" },
        {
          key = 4,
          type = "blueprint-book",
          item_name = "blueprint-book",
          label = "b",
          icons = {},
          description = "",
          children = {
            {
              key = 2,
              type = "upgrade-planner",
              item_name = "upgrade-planner",
              label = "u",
              icons = {},
              description = "",
            },
          },
        },
      }, BlueprintLogic.item_nodes(inventory, ITEM_MAIN))
    end)
  end)

  describe(".resolve", function()
    local leaf = record({ type = "blueprint", label = "leaf", is_preview = false })
    local roots = {
      record({ type = "blueprint-book", label = "book", is_preview = false, contents = { [3] = leaf } }),
    }

    it("walks books by index and checks type and label", function()
      assert.are.equal(leaf, BlueprintLogic.resolve(roots, { 1, 3 }, "blueprint", "leaf"))
    end)

    it("returns nil when the record changed", function()
      assert.is_nil(BlueprintLogic.resolve(roots, { 1, 3 }, "blueprint", "renamed"))
      assert.is_nil(BlueprintLogic.resolve(roots, { 1, 3 }, "deconstruction-planner", "leaf"))
      assert.is_nil(BlueprintLogic.resolve(roots, { 1, 9 }, "blueprint", "leaf"))
      assert.is_nil(BlueprintLogic.resolve(roots, { 2 }, "blueprint", "leaf"))
    end)

    it("returns nil for a preview record or a path through a preview book", function()
      local preview_roots = {
        record({ type = "blueprint-book", label = "book", is_preview = true, contents = { [1] = leaf } }),
        record({ type = "blueprint", label = "p", is_preview = true }),
      }

      assert.is_nil(BlueprintLogic.resolve(preview_roots, { 1, 1 }, "blueprint", "leaf"))
      assert.is_nil(BlueprintLogic.resolve(preview_roots, { 2 }, "blueprint", "p"))
    end)
  end)

  describe(".resolve_item", function()
    local leaf = stack({ is_blueprint = true, name = "blueprint", label = "leaf" })
    local inventory = { stack({ valid_for_read = false }), book_stack("book", { leaf }) }

    it("walks book items by slot and checks kind and label", function()
      assert.are.equal(leaf, BlueprintLogic.resolve_item(inventory, { 2, 1 }, ITEM_MAIN, "blueprint", "leaf"))
    end)

    it("returns nil for an emptied slot, a changed item or an out-of-range slot", function()
      assert.is_nil(BlueprintLogic.resolve_item(inventory, { 1 }, ITEM_MAIN, "blueprint", "leaf"))
      assert.is_nil(BlueprintLogic.resolve_item(inventory, { 2, 1 }, ITEM_MAIN, "blueprint", "renamed"))
      assert.is_nil(BlueprintLogic.resolve_item(inventory, { 2, 1 }, ITEM_MAIN, "upgrade-planner", "leaf"))
      assert.is_nil(BlueprintLogic.resolve_item(inventory, { 2, 5 }, ITEM_MAIN, "blueprint", "leaf"))
      assert.is_nil(BlueprintLogic.resolve_item(inventory, { 9 }, ITEM_MAIN, "blueprint", "leaf"))
    end)
  end)
end)
