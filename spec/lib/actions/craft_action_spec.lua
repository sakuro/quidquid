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

  describe(".resolve_craftable", function()
    it("returns the craft-no-recipe error for an item candidate with no matching recipe", function()
      local player = fake_player({}, false)

      local recipe, error_key = CraftAction.resolve_craftable({ type = "item", id = "iron-plate" }, player)

      assert.is_nil(recipe)
      assert.are.equal("quidquid.action-craft-no-recipe", error_key)
    end)

    it("returns no recipe and no error for a recipe candidate with no matching force recipe", function()
      local player = fake_player({}, false)

      local recipe, error_key = CraftAction.resolve_craftable({ type = "recipe", id = "iron-plate" }, player)

      assert.is_nil(recipe)
      assert.is_nil(error_key)
    end)

    it("returns the hand-crafting-disabled error when the recipe can't be hand-crafted", function()
      local player = fake_player({ ["iron-plate"] = "recipe-token" }, true)

      local recipe, error_key = CraftAction.resolve_craftable({ id = "iron-plate" }, player)

      assert.is_nil(recipe)
      assert.are.equal("quidquid.action-craft-hand-crafting-disabled", error_key)
    end)

    it("returns the recipe with no error when it can be hand-crafted", function()
      local player = fake_player({ ["iron-plate"] = "recipe-token" }, false)

      local recipe, error_key = CraftAction.resolve_craftable({ id = "iron-plate" }, player)

      assert.are.equal("recipe-token", recipe)
      assert.is_nil(error_key)
    end)
  end)
end)
