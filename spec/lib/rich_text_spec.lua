local rich_text = require("lib.rich_text")

describe("rich_text", function()
  describe(".mask_tags", function()
    it("masks tags and preserves their byte length", function()
      local value = "[item=iron-plate] Cargo"
      local masked = rich_text.mask_tags(value)

      assert.are.equal(string.rep(" ", #"[item=iron-plate]") .. " Cargo", masked)
      assert.are.equal(#value, #masked)
    end)

    it("leaves plain text unchanged", function()
      assert.are.equal("Cargo Express", rich_text.mask_tags("Cargo Express"))
    end)
  end)

  describe(".icon_list_caption", function()
    local function icon(item)
      return "[x=" .. item.name .. "]"
    end

    it("concatenates every item when under the limit", function()
      local items = { { name = "a" }, { name = "b" } }

      local result = rich_text.icon_list_caption(items, icon, 5, "mod.more-key")

      assert.are.same({ "", "[x=a], [x=b]" }, result)
    end)

    it("concatenates every item with no trailing entry when exactly at the limit", function()
      local items = { { name = "a" }, { name = "b" }, { name = "c" } }

      local result = rich_text.icon_list_caption(items, icon, 3, "mod.more-key")

      assert.are.same({ "", "[x=a], [x=b], [x=c]" }, result)
    end)

    it("truncates to the limit and names the correct remainder past it", function()
      local items = { { name = "a" }, { name = "b" }, { name = "c" }, { name = "d" } }

      local result = rich_text.icon_list_caption(items, icon, 3, "mod.more-key")

      assert.are.same({ "", "[x=a], [x=b], [x=c], ", { "mod.more-key", 1 } }, result)
    end)

    it("uses a custom separator when given", function()
      local items = { { name = "a" }, { name = "b" } }

      local result = rich_text.icon_list_caption(items, icon, 5, "mod.more-key", "\n")

      assert.are.same({ "", "[x=a]\n[x=b]" }, result)
    end)

    it("uses the custom separator for the trailing entry before truncation too", function()
      local items = { { name = "a" }, { name = "b" }, { name = "c" } }

      local result = rich_text.icon_list_caption(items, icon, 2, "mod.more-key", "\n")

      assert.are.same({ "", "[x=a]\n[x=b]\n", { "mod.more-key", 1 } }, result)
    end)
  end)

  describe(".searchable", function()
    local function text_of(value)
      return (rich_text.searchable(value))
    end

    it("leaves plain text and its origins untouched", function()
      local text, origins = rich_text.searchable("abc")

      assert.are.equal("abc", text)
      assert.are.same({ 1, 2, 3 }, origins)
    end)

    it("keeps an icon tag's value and marks it tag-derived", function()
      local text, origins = rich_text.searchable("[item=rail]x")

      assert.are.equal("rail x", text)
      assert.are.same({ false, false, false, false, false, 12 }, origins)
    end)

    it("separates tag text from text on both sides", function()
      assert.are.equal("鉄道 rail 駅", text_of("鉄道[item=rail]駅"))
    end)

    it("does not double an existing space", function()
      assert.are.equal("a rail b", text_of("a [item=rail] b"))
    end)

    it("separates adjacent tags", function()
      assert.are.equal("iron-plate copper-plate", text_of("[item=iron-plate][item=copper-plate]"))
    end)

    it("removes the quality parameter", function()
      assert.are.equal("iron-plate 鉄板", text_of("[item=iron-plate,quality=rare]鉄板"))
    end)

    it("drops everything up to the last slash or dot", function()
      assert.are.equal("iron-plate", text_of("[img=item/iron-plate]"))
      assert.are.equal("iron-plate", text_of("[img=item.iron-plate]"))
    end)

    it("keeps the name of a tag without a value", function()
      assert.are.equal("space-age", text_of("[space-age]"))
    end)

    it("keeps only the text of a tooltip tag", function()
      assert.are.equal("hint", text_of("[tooltip=hint,some.key]"))
    end)

    it("removes gps and special-item tags entirely", function()
      assert.are.equal("a", text_of("[gps=1,2,nauvis]a"))
      assert.are.equal("a", text_of("a[special-item=0eNqrVkrKLMlJVbSSa]"))
    end)

    it("removes color and font tags but keeps the enclosed text as ordinary text", function()
      local text, origins = rich_text.searchable("[color=red]赤[/color]")

      assert.are.equal("赤", text)
      assert.are.same({ 12, 13, 14 }, origins)
      assert.are.equal("b", text_of("[font=default-bold]b[.font]"))
      assert.are.equal("c", text_of("[color=1,0,0]c[.color]"))
    end)

    it("inserts no separator around a removed tag", function()
      assert.are.equal("ab", text_of("a[color=red]b[/color]"))
    end)
  end)

  describe(".map_ranges", function()
    it("maps plain-text ranges back to original bytes", function()
      local _, origins = rich_text.searchable("[item=rail]xy")

      assert.are.same(
        { { start_byte = 12, end_byte = 13 } },
        rich_text.map_ranges({ { start_byte = 6, end_byte = 7 } }, origins)
      )
    end)

    it("drops tag-derived bytes", function()
      local _, origins = rich_text.searchable("[item=rail]x")

      assert.are.same({}, rich_text.map_ranges({ { start_byte = 1, end_byte = 4 } }, origins))
    end)

    it("splits a range that crosses a tag", function()
      local _, origins = rich_text.searchable("a[item=rail]b")
      -- searchable: "a rail b"; the range covers all of it.

      assert.are.same(
        { { start_byte = 1, end_byte = 1 }, { start_byte = 13, end_byte = 13 } },
        rich_text.map_ranges({ { start_byte = 1, end_byte = 8 } }, origins)
      )
    end)

    it("splits a range across a removed tag", function()
      local _, origins = rich_text.searchable("a[color=red]b")

      assert.are.same(
        { { start_byte = 1, end_byte = 1 }, { start_byte = 13, end_byte = 13 } },
        rich_text.map_ranges({ { start_byte = 1, end_byte = 2 } }, origins)
      )
    end)

    it("returns an empty list for nil ranges", function()
      assert.are.same({}, rich_text.map_ranges(nil, {}))
    end)
  end)
end)
