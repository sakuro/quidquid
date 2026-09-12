local TranslationCache = require("lib.translation_cache")

describe("TranslationCache", function()
  before_each(function()
    storage = {}
  end)

  describe(":get", function()
    it("returns nil for a locale with no entries", function()
      assert.is_nil(TranslationCache:get("items", "en", "iron-plate"))
    end)

    it("returns nil for an untranslated item in a known locale", function()
      TranslationCache:set("items", "en", "iron-plate", "Iron Plate")

      assert.is_nil(TranslationCache:get("items", "en", "copper-plate"))
    end)
  end)

  describe(":set / :get", function()
    it("returns what was set", function()
      TranslationCache:set("items", "en", "iron-plate", "Iron Plate")

      assert.are.equal("Iron Plate", TranslationCache:get("items", "en", "iron-plate"))
    end)

    it("keeps different locales independent", function()
      TranslationCache:set("items", "en", "iron-plate", "Iron Plate")
      TranslationCache:set("items", "ja", "iron-plate", "鉄板")

      assert.are.equal("Iron Plate", TranslationCache:get("items", "en", "iron-plate"))
      assert.are.equal("鉄板", TranslationCache:get("items", "ja", "iron-plate"))
    end)

    it("keeps different namespaces independent even with the same locale and name", function()
      TranslationCache:set("items", "en", "steam-power", "Item named steam-power")
      TranslationCache:set("technologies", "en", "steam-power", "Steam power")

      assert.are.equal("Item named steam-power", TranslationCache:get("items", "en", "steam-power"))
      assert.are.equal("Steam power", TranslationCache:get("technologies", "en", "steam-power"))
    end)
  end)

  describe(":is_complete / :mark_complete", function()
    it("is not complete by default", function()
      assert.is_false(TranslationCache:is_complete("items", "en"))
    end)

    it("becomes complete after mark_complete", function()
      TranslationCache:mark_complete("items", "en")

      assert.is_true(TranslationCache:is_complete("items", "en"))
    end)

    it("keeps different locales' completion independent", function()
      TranslationCache:mark_complete("items", "en")

      assert.is_false(TranslationCache:is_complete("items", "ja"))
    end)

    it("keeps different namespaces' completion independent", function()
      TranslationCache:mark_complete("items", "en")

      assert.is_false(TranslationCache:is_complete("technologies", "en"))
    end)
  end)

  describe(":clear", function()
    it("resets both entries and completion flags together", function()
      TranslationCache:set("items", "en", "iron-plate", "Iron Plate")
      TranslationCache:mark_complete("items", "en")

      TranslationCache:clear()

      assert.is_nil(TranslationCache:get("items", "en", "iron-plate"))
      assert.is_false(TranslationCache:is_complete("items", "en"))
    end)
  end)
end)
