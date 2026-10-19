local TemporaryRequestEditorLogic = require("lib.temporary_request_editor_logic")

describe("TemporaryRequestEditorLogic", function()
  describe(".next_stack_multiple", function()
    it("rounds up to the next multiple when below a multiple", function()
      assert.are.equal(50, TemporaryRequestEditorLogic.next_stack_multiple(30, 50))
    end)

    it("advances to the next multiple when already at an exact multiple", function()
      assert.are.equal(100, TemporaryRequestEditorLogic.next_stack_multiple(50, 50))
    end)

    it("rounds up from a value between two multiples", function()
      assert.are.equal(100, TemporaryRequestEditorLogic.next_stack_multiple(80, 50))
    end)

    it("advances from zero to the first stack", function()
      assert.are.equal(50, TemporaryRequestEditorLogic.next_stack_multiple(0, 50))
    end)
  end)

  describe(".previous_stack_multiple", function()
    it("rounds down to zero when below a single stack", function()
      assert.are.equal(0, TemporaryRequestEditorLogic.previous_stack_multiple(30, 50))
    end)

    it("recedes to the previous multiple when already at an exact multiple", function()
      assert.are.equal(0, TemporaryRequestEditorLogic.previous_stack_multiple(50, 50))
    end)

    it("rounds down from a value between two multiples", function()
      assert.are.equal(50, TemporaryRequestEditorLogic.previous_stack_multiple(80, 50))
    end)

    it("stays at zero when already at zero", function()
      assert.are.equal(0, TemporaryRequestEditorLogic.previous_stack_multiple(0, 50))
    end)
  end)

  describe(".next_quantity and .previous_quantity", function()
    it("increments and decrements recipe craft counts by one", function()
      assert.are.equal(4, TemporaryRequestEditorLogic.next_quantity(3))
      assert.are.equal(2, TemporaryRequestEditorLogic.previous_quantity(3))
    end)

    it("does not decrement below zero", function()
      assert.are.equal(0, TemporaryRequestEditorLogic.previous_quantity(0))
    end)
  end)

  describe(".recipe_ingredients", function()
    it("converts item ingredients to requested amounts and skips fluids", function()
      assert.are.same(
        {
          { name = "iron-plate", amount = 6, quality = "rare" },
        },
        TemporaryRequestEditorLogic.recipe_ingredients({
          { type = "item", name = "iron-plate", amount = 2 },
          { type = "fluid", name = "water", amount = 10 },
        }, 3, "rare")
      )
    end)
  end)

  describe(".recipe_craft_count", function()
    it("uses the smallest complete ingredient count", function()
      assert.are.equal(
        2,
        TemporaryRequestEditorLogic.recipe_craft_count({ ["iron-plate"] = 6, ["copper-plate"] = 2 }, {
          { type = "item", name = "iron-plate", amount = 3 },
          { type = "item", name = "copper-plate", amount = 1 },
        })
      )
    end)

    it("returns nil when an ingredient request does not exist", function()
      assert.is_nil(TemporaryRequestEditorLogic.recipe_craft_count({ ["iron-plate"] = 6 }, {
        { type = "item", name = "iron-plate", amount = 3 },
        { type = "item", name = "copper-plate", amount = 1 },
      }))
    end)
  end)

  describe(".plan_confirm", function()
    local function plan(quantity, ingredients, held, others)
      return TemporaryRequestEditorLogic.plan_confirm(quantity, ingredients, function(name, quality)
        return held[name .. ":" .. quality] or 0
      end, function(name, quality)
        return others[name .. ":" .. quality] or 0
      end)
    end

    local iron = { { name = "iron-plate", amount = 150, quality = "normal" } }

    it("removes when the entered quantity is 0, whatever is held", function()
      assert.are.equal("remove_zero", (plan(0, {}, {}, {})))
      assert.are.equal("remove_zero", (plan(0, iron, { ["iron-plate:normal"] = 80 }, {})))
    end)

    it("requests the whole amount when nothing else requests it", function()
      local action, requests = plan(150, iron, {}, {})

      assert.are.equal("set", action)
      assert.are.same({ { name = "iron-plate", quality = "normal", min = 150 } }, requests)
    end)

    it("requests only the part other requests do not cover", function()
      local action, requests = plan(150, iron, { ["iron-plate:normal"] = 120 }, { ["iron-plate:normal"] = 100 })

      assert.are.equal("set", action)
      assert.are.same({ { name = "iron-plate", quality = "normal", min = 50 } }, requests)
    end)

    it("removes as satisfied when the amount is already held", function()
      local action, requests = plan(150, iron, { ["iron-plate:normal"] = 150 }, {})

      assert.are.equal("remove_satisfied", action)
      assert.are.same({}, requests)
    end)

    it("removes as covered when other requests already ask for the amount", function()
      assert.are.equal("remove_covered", (plan(150, iron, {}, { ["iron-plate:normal"] = 150 })))
      assert.are.equal(
        "remove_covered",
        (plan(100, iron, { ["iron-plate:normal"] = 20 }, { ["iron-plate:normal"] = 150 }))
      )
    end)

    it("ignores other requests of a different quality", function()
      local action = plan(150, iron, {}, { ["iron-plate:rare"] = 500 })

      assert.are.equal("set", action)
    end)

    it("requests only the ingredients that are neither held nor covered", function()
      local ingredients = {
        { name = "iron-plate", amount = 6, quality = "normal" },
        { name = "copper-plate", amount = 2, quality = "normal" },
        { name = "steel-plate", amount = 4, quality = "normal" },
      }
      local action, requests = plan(
        1,
        ingredients,
        { ["iron-plate:normal"] = 6 },
        { ["copper-plate:normal"] = 2, ["steel-plate:normal"] = 1 }
      )

      assert.are.equal("set", action)
      assert.are.same({ { name = "steel-plate", quality = "normal", min = 3 } }, requests)
    end)

    it("removes as covered, not satisfied, when holdings and requests together suffice", function()
      local ingredients = {
        { name = "iron-plate", amount = 6, quality = "normal" },
        { name = "copper-plate", amount = 2, quality = "normal" },
      }

      assert.are.equal(
        "remove_covered",
        (plan(1, ingredients, { ["iron-plate:normal"] = 6 }, { ["copper-plate:normal"] = 2 }))
      )
    end)
  end)

  describe(".is_valid_quantity", function()
    it("rejects nil (failed to parse at all)", function()
      assert.is_false(TemporaryRequestEditorLogic.is_valid_quantity(nil))
    end)

    it("rejects a non-whole number", function()
      assert.is_false(TemporaryRequestEditorLogic.is_valid_quantity(1.5))
    end)

    it("rejects a negative whole number", function()
      assert.is_false(TemporaryRequestEditorLogic.is_valid_quantity(-1))
    end)

    it("accepts zero", function()
      assert.is_true(TemporaryRequestEditorLogic.is_valid_quantity(0))
    end)

    it("accepts a positive whole number", function()
      assert.is_true(TemporaryRequestEditorLogic.is_valid_quantity(200))
    end)
  end)
end)
