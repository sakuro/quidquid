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
end)
