local CraftAction = require("lib.actions.craft_action")

local function fake_player(recipes, hand_crafting_disabled)
  return {
    force = {
      recipes = recipes,
      get_hand_crafting_disabled_for_recipe = function(_recipe)
        return hand_crafting_disabled
      end,
    },
  }
end

describe("CraftAction", function()
  after_each(function()
    _G.game = nil
  end)

  describe(".count_of", function()
    it("returns a function that always yields the given count, ignoring player and recipe", function()
      local count_for = CraftAction.count_of(5)

      assert.are.equal(5, count_for(nil, nil))
      assert.are.equal(5, count_for({}, "recipe-token"))
    end)
  end)

  describe(".max_craftable", function()
    it("returns the player's craftable count when it is positive", function()
      local player = {
        get_craftable_count = function(_recipe)
          return 3
        end,
      }

      assert.are.equal(3, CraftAction.max_craftable(player, "recipe-token"))
    end)

    it("floors to 1 when the player's craftable count is zero", function()
      local player = {
        get_craftable_count = function(_recipe)
          return 0
        end,
      }

      assert.are.equal(1, CraftAction.max_craftable(player, "recipe-token"))
    end)
  end)

  describe(".is_applicable", function()
    it("returns false when the player index does not resolve to a player", function()
      _G.game = {
        get_player = function(_index)
          return nil
        end,
      }

      local applicable = CraftAction.is_applicable({ id = "iron-plate" }, 1)

      assert.is_false(applicable)
    end)

    it("keeps an item candidate applicable when the recipe is not known to the player's force", function()
      _G.game = {
        get_player = function(_index)
          return fake_player({}, false)
        end,
      }

      local applicable = CraftAction.is_applicable({ type = "item", id = "iron-plate" }, 1)

      assert.is_true(applicable)
    end)

    it("keeps an item candidate applicable when no same-named recipe exists", function()
      _G.game = {
        get_player = function(_index)
          return fake_player({}, false)
        end,
      }

      local applicable = CraftAction.is_applicable({ type = "item", id = "iron-plate" }, 1)

      assert.is_true(applicable)
    end)

    it("returns false for a recipe candidate when the force has no matching recipe", function()
      _G.game = {
        get_player = function(_index)
          return fake_player({}, false)
        end,
      }

      local applicable = CraftAction.is_applicable({ type = "recipe", id = "iron-plate" }, 1)

      assert.is_false(applicable)
    end)

    it("returns false when hand crafting is disabled for the recipe", function()
      _G.game = {
        get_player = function(_index)
          return fake_player({ ["iron-plate"] = "recipe-token" }, true)
        end,
      }

      local applicable = CraftAction.is_applicable({ id = "iron-plate" }, 1)

      assert.is_false(applicable)
    end)

    it("returns true when the recipe exists and hand crafting is enabled", function()
      _G.game = {
        get_player = function(_index)
          return fake_player({ ["iron-plate"] = "recipe-token" }, false)
        end,
      }

      local applicable = CraftAction.is_applicable({ id = "iron-plate" }, 1)

      assert.is_true(applicable)
    end)
  end)
end)
