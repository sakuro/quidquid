local CraftAction = require("lib.actions.craft_action")

local function fake_character(categories)
  return { prototype = { crafting_categories = categories or { crafting = true } } }
end

local function fake_player(options)
  options = options or {}
  return {
    force = {
      recipes = options.recipes or {},
      get_hand_crafting_disabled_for_recipe = function(_recipe)
        return options.hand_crafting_disabled or false
      end,
    },
    character = options.character == nil and fake_character() or options.character,
    get_craftable_count = function(_recipe)
      return options.craftable_count or 1
    end,
  }
end

local function fake_recipe(overrides)
  local recipe = {
    enabled = true,
    categories = { "crafting" },
  }
  for key, value in pairs(overrides or {}) do
    recipe[key] = value
  end
  return recipe
end

describe("CraftAction", function()
  after_each(function()
    _G.game = nil
  end)

  describe(".fixed_count", function()
    it("returns a function that always yields the given count, ignoring player and recipe", function()
      local count_for = CraftAction.fixed_count(5)

      assert.are.equal(5, count_for(nil, nil))
      assert.are.equal(5, count_for({}, "recipe-token"))
    end)
  end)

  describe(".max_craftable", function()
    it("returns the player's craftable count", function()
      -- resolve_craftable already rejects a zero craftable count before this is
      -- ever called, so there's no flooring here -- only the pass-through case.
      local player = {
        get_craftable_count = function(_recipe)
          return 3
        end,
      }

      assert.are.equal(3, CraftAction.max_craftable(player, "recipe-token"))
    end)
  end)

  describe(".is_hand_craftable", function()
    it("is true when the character can craft at least one of the recipe's categories", function()
      local recipe = fake_recipe({ categories = { "smelting", "crafting" } })
      local character = fake_character({ crafting = true })

      assert.is_true(CraftAction.is_hand_craftable(recipe, character))
    end)

    it("is false when none of the recipe's categories are hand-craftable", function()
      local recipe = fake_recipe({ categories = { "smelting" } })
      local character = fake_character({ crafting = true })

      assert.is_false(CraftAction.is_hand_craftable(recipe, character))
    end)

    it("is false when there is no character", function()
      local recipe = fake_recipe()

      assert.is_false(CraftAction.is_hand_craftable(recipe, nil))
    end)
  end)

  describe(".resolve_craftable", function()
    it("returns the craft-no-recipe error for an item candidate with no matching recipe", function()
      local player = fake_player({ recipes = {} })

      local recipe, reason_locale_key = CraftAction.resolve_craftable({ type = "item", id = "iron-plate" }, player)

      assert.is_nil(recipe)
      assert.are.equal("quidquid.action-craft-no-recipe", reason_locale_key)
    end)

    it("returns no recipe and no error for a recipe candidate with no matching force recipe", function()
      local player = fake_player({ recipes = {} })

      local recipe, reason_locale_key = CraftAction.resolve_craftable({ type = "recipe", id = "iron-plate" }, player)

      assert.is_nil(recipe)
      assert.is_nil(reason_locale_key)
    end)

    it("returns the not-researched error for an unresearched recipe", function()
      local player = fake_player({ recipes = { ["iron-plate"] = fake_recipe({ enabled = false }) } })

      local recipe, reason_locale_key = CraftAction.resolve_craftable({ id = "iron-plate" }, player)

      assert.is_nil(recipe)
      assert.are.equal("quidquid.action-craft-not-researched", reason_locale_key)
    end)

    it("returns the hand-crafting-disabled error when the force disabled it", function()
      local player = fake_player({ recipes = { ["iron-plate"] = fake_recipe() }, hand_crafting_disabled = true })

      local recipe, reason_locale_key = CraftAction.resolve_craftable({ id = "iron-plate" }, player)

      assert.is_nil(recipe)
      assert.are.equal("quidquid.action-craft-hand-crafting-disabled", reason_locale_key)
    end)

    it("returns the hand-crafting-disabled error for a recipe with no hand-craftable category", function()
      -- Same locale key as the force-disabled case: Factorio's own message doesn't
      -- distinguish the two either.
      local player = fake_player({
        recipes = { ["iron-plate"] = fake_recipe({ categories = { "smelting" } }) },
      })

      local recipe, reason_locale_key = CraftAction.resolve_craftable({ id = "iron-plate" }, player)

      assert.is_nil(recipe)
      assert.are.equal("quidquid.action-craft-hand-crafting-disabled", reason_locale_key)
    end)

    it("returns the not-enough-ingredients error when nothing is craftable", function()
      local player = fake_player({
        recipes = { ["iron-plate"] = fake_recipe() },
        craftable_count = 0,
      })

      local recipe, reason_locale_key = CraftAction.resolve_craftable({ id = "iron-plate" }, player)

      assert.is_nil(recipe)
      assert.are.equal("quidquid.action-craft-not-enough-ingredients", reason_locale_key)
    end)

    it("returns the recipe with no error when it can be hand-crafted", function()
      local player = fake_player({
        recipes = { ["iron-plate"] = fake_recipe() },
        craftable_count = 3,
      })

      local recipe, reason_locale_key = CraftAction.resolve_craftable({ id = "iron-plate" }, player)

      assert.are.same(fake_recipe(), recipe)
      assert.is_nil(reason_locale_key)
    end)
  end)
end)
