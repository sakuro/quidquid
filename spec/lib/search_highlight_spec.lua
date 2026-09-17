local search_highlight = require("lib.search_highlight")

describe("search_highlight", function()
  describe(".positions_to_ranges", function()
    it("maps normalized positions to original byte ranges", function()
      local position_map = {
        { start_byte = 1, end_byte = 1 },
        { start_byte = 2, end_byte = 2 },
        { start_byte = 3, end_byte = 4 },
      }

      assert.are.same({
        { start_byte = 3, end_byte = 4 },
        { start_byte = 1, end_byte = 1 },
      }, search_highlight.positions_to_ranges(position_map, { 3, 1 }))
    end)
  end)

  describe(".highlight", function()
    it("wraps matching UTF-8 byte ranges in the bold font tag", function()
      assert.are.equal(
        "Iron [font=default-bold]plate[/font]",
        search_highlight.highlight("Iron plate", { { start_byte = 6, end_byte = 10 } })
      )
    end)

    it("maps multiple normalized positions back to one expanded source character", function()
      local position_map = {
        { start_byte = 1, end_byte = 1 },
        { start_byte = 2, end_byte = 2 },
        { start_byte = 5, end_byte = 6 },
        { start_byte = 5, end_byte = 6 },
        { start_byte = 7, end_byte = 7 },
      }

      assert.are.same({
        { start_byte = 5, end_byte = 6 },
        { start_byte = 5, end_byte = 6 },
      }, search_highlight.positions_to_ranges(position_map, { 3, 4 }))
    end)

    it("merges overlapping and adjacent ranges", function()
      assert.are.equal(
        "a[font=default-bold]bcde[/font]f",
        search_highlight.highlight("abcdef", {
          { start_byte = 2, end_byte = 3 },
          { start_byte = 4, end_byte = 5 },
          { start_byte = 3, end_byte = 4 },
        })
      )
    end)

    it("keeps a multibyte source character intact", function()
      assert.are.equal(
        "Stra[font=default-bold]ß[/font]e",
        search_highlight.highlight("Straße", { { start_byte = 5, end_byte = 6 } })
      )
    end)

    it("leaves a value unchanged without ranges", function()
      assert.are.equal("iron-plate", search_highlight.highlight("iron-plate", {}))
    end)
  end)
end)
