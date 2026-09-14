local TemporaryRequestAction = require("lib.actions.temporary_request_action")

describe("TemporaryRequestAction", function()
  describe(".find_section_index_by_group", function()
    it("returns the index of a matching group", function()
      local groups = { "", "quidquid-group", "other" }

      assert.are.equal(2, TemporaryRequestAction.find_section_index_by_group(groups, "quidquid-group"))
    end)

    it("returns nil when no group matches", function()
      local groups = { "", "other" }

      assert.is_nil(TemporaryRequestAction.find_section_index_by_group(groups, "quidquid-group"))
    end)

    it("returns nil for an empty list", function()
      assert.is_nil(TemporaryRequestAction.find_section_index_by_group({}, "quidquid-group"))
    end)
  end)

  describe(".find_slot_index", function()
    it("returns the index of an existing slot matching item and quality", function()
      local existing = {
        { value = { name = "copper-plate", quality = "normal" } },
        { value = { name = "iron-plate", quality = "normal" } },
      }

      assert.are.equal(2, TemporaryRequestAction.find_slot_index(existing, "iron-plate", "normal"))
    end)

    it("does not match a slot with the same name but a different quality", function()
      local existing = {
        { value = { name = "iron-plate", quality = "legendary" } },
      }

      assert.are.equal(2, TemporaryRequestAction.find_slot_index(existing, "iron-plate", "normal"))
    end)

    it("returns the next free index when nothing matches", function()
      local existing = {
        { value = { name = "copper-plate", quality = "normal" } },
      }

      assert.are.equal(2, TemporaryRequestAction.find_slot_index(existing, "iron-plate", "normal"))
    end)

    it("returns the next free index for an empty list", function()
      assert.are.equal(1, TemporaryRequestAction.find_slot_index({}, "iron-plate", "normal"))
    end)

    it("skips slots with a nil value", function()
      local existing = {
        { value = nil },
        { value = { name = "iron-plate", quality = "normal" } },
      }

      assert.are.equal(2, TemporaryRequestAction.find_slot_index(existing, "iron-plate", "normal"))
    end)
  end)

  describe(".combined_target", function()
    it("returns the count of the matching filter entry", function()
      local filters = {
        { name = "copper-plate", quality = "normal", count = 50 },
        { name = "iron-plate", quality = "normal", count = 150 },
      }

      assert.are.equal(150, TemporaryRequestAction.combined_target(filters, "iron-plate", "normal"))
    end)

    it("ignores a filter for a different item or quality", function()
      local filters = {
        { name = "iron-plate", quality = "legendary", count = 999 },
        { name = "copper-plate", quality = "normal", count = 50 },
      }

      assert.are.equal(0, TemporaryRequestAction.combined_target(filters, "iron-plate", "normal"))
    end)

    it("returns 0 when nothing matches", function()
      assert.are.equal(0, TemporaryRequestAction.combined_target({}, "iron-plate", "normal"))
    end)
  end)
end)
