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

  describe(".joined_list", function()
    local function icon(item)
      return "[x=" .. item.name .. "]"
    end

    it("concatenates every item when under the limit", function()
      local items = { { name = "a" }, { name = "b" } }

      local result = rich_text.joined_list(items, icon, 5, "mod.more-key")

      assert.are.same({ "", "[x=a], [x=b]" }, result)
    end)

    it("concatenates every item with no trailing entry when exactly at the limit", function()
      local items = { { name = "a" }, { name = "b" }, { name = "c" } }

      local result = rich_text.joined_list(items, icon, 3, "mod.more-key")

      assert.are.same({ "", "[x=a], [x=b], [x=c]" }, result)
    end)

    it("truncates to the limit and names the correct remainder past it", function()
      local items = { { name = "a" }, { name = "b" }, { name = "c" }, { name = "d" } }

      local result = rich_text.joined_list(items, icon, 3, "mod.more-key")

      assert.are.same({ "", "[x=a], [x=b], [x=c], ", { "mod.more-key", 1 } }, result)
    end)
  end)
end)
