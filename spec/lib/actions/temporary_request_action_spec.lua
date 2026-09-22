local TemporaryRequestAction = require("lib.actions.temporary_request_action")

describe("TemporaryRequestAction", function()
  after_each(function()
    _G.game = nil
    _G.defines = nil
  end)

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

  describe(".find_or_next_slot_index", function()
    it("returns the index of an existing slot matching item and quality", function()
      local existing = {
        { value = { name = "copper-plate", quality = "normal" } },
        { value = { name = "iron-plate", quality = "normal" } },
      }

      assert.are.equal(2, TemporaryRequestAction.find_or_next_slot_index(existing, "iron-plate", "normal"))
    end)

    it("does not match a slot with the same name but a different quality", function()
      local existing = {
        { value = { name = "iron-plate", quality = "legendary" } },
      }

      assert.are.equal(2, TemporaryRequestAction.find_or_next_slot_index(existing, "iron-plate", "normal"))
    end)

    it("returns the next free index when nothing matches", function()
      local existing = {
        { value = { name = "copper-plate", quality = "normal" } },
      }

      assert.are.equal(2, TemporaryRequestAction.find_or_next_slot_index(existing, "iron-plate", "normal"))
    end)

    it("returns the next free index for an empty list", function()
      assert.are.equal(1, TemporaryRequestAction.find_or_next_slot_index({}, "iron-plate", "normal"))
    end)

    it("skips slots with a nil value", function()
      local existing = {
        { value = nil },
        { value = { name = "iron-plate", quality = "normal" } },
      }

      assert.are.equal(2, TemporaryRequestAction.find_or_next_slot_index(existing, "iron-plate", "normal"))
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

  describe(".resolve_requestable", function()
    it("is always requestable for an item candidate", function()
      local requestable, reason_locale_key = TemporaryRequestAction.resolve_requestable(
        { type = "item" },
        { recipes = {} }
      )

      assert.is_true(requestable)
      assert.is_nil(reason_locale_key)
    end)

    it("returns no error for a recipe candidate with no matching force recipe", function()
      local requestable, reason_locale_key = TemporaryRequestAction.resolve_requestable(
        { type = "recipe", id = "advanced-oil-processing" },
        {
          recipes = {},
        }
      )

      assert.is_false(requestable)
      assert.is_nil(reason_locale_key)
    end)

    it("returns the no-item-ingredients error for a recipe with only fluid ingredients", function()
      local force = {
        recipes = {
          ["advanced-oil-processing"] = {
            ingredients = {
              { type = "fluid", name = "water" },
              { type = "fluid", name = "crude-oil" },
            },
          },
        },
      }

      local requestable, reason_locale_key =
        TemporaryRequestAction.resolve_requestable({ type = "recipe", id = "advanced-oil-processing" }, force)

      assert.is_false(requestable)
      assert.are.equal("quidquid.action-temporary-request-no-item-ingredients", reason_locale_key)
    end)

    it("is requestable for a recipe with at least one item ingredient", function()
      local force = {
        recipes = {
          ["iron-plate"] = {
            ingredients = { { type = "item", name = "iron-ore" } },
          },
        },
      }

      local requestable, reason_locale_key =
        TemporaryRequestAction.resolve_requestable({ type = "recipe", id = "iron-plate" }, force)

      assert.is_true(requestable)
      assert.is_nil(reason_locale_key)
    end)
  end)

  describe(".is_available", function()
    before_each(function()
      _G.defines = { logistic_member_index = { character_requester = 1 } }
    end)

    it("returns false when the player no longer exists", function()
      _G.game = {
        get_player = function(_player_index)
          return nil
        end,
      }

      assert.is_false(TemporaryRequestAction.is_available(1))
    end)

    it("returns false when the player has no character", function()
      _G.game = {
        get_player = function(_player_index)
          return { character = nil }
        end,
      }

      assert.is_false(TemporaryRequestAction.is_available(1))
    end)

    it("returns false when the character has no requester logistic point", function()
      _G.game = {
        get_player = function(_player_index)
          return {
            character = {
              get_logistic_point = function(_member_index)
                return nil
              end,
            },
          }
        end,
      }

      assert.is_false(TemporaryRequestAction.is_available(1))
    end)

    it("returns true when the character has a requester logistic point", function()
      _G.game = {
        get_player = function(_player_index)
          return {
            character = {
              get_logistic_point = function(_member_index)
                return { filters = {} }
              end,
            },
          }
        end,
      }

      assert.is_true(TemporaryRequestAction.is_available(1))
    end)
  end)
end)
