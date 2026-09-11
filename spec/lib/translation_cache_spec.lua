local TranslationCache = require("lib.translation_cache")

describe("TranslationCache", function()
  before_each(function()
    storage = {}
  end)

  describe(":get", function()
    it("returns nil for a locale with no entries", function()
      assert.is_nil(TranslationCache:get("en", "iron-plate"))
    end)

    it("returns nil for an untranslated item in a known locale", function()
      TranslationCache:set("en", "iron-plate", "Iron Plate")

      assert.is_nil(TranslationCache:get("en", "copper-plate"))
    end)
  end)

  describe(":set / :get", function()
    it("returns what was set", function()
      TranslationCache:set("en", "iron-plate", "Iron Plate")

      assert.are.equal("Iron Plate", TranslationCache:get("en", "iron-plate"))
    end)

    it("keeps different locales independent", function()
      TranslationCache:set("en", "iron-plate", "Iron Plate")
      TranslationCache:set("ja", "iron-plate", "鉄板")

      assert.are.equal("Iron Plate", TranslationCache:get("en", "iron-plate"))
      assert.are.equal("鉄板", TranslationCache:get("ja", "iron-plate"))
    end)
  end)

  describe(":is_complete / :mark_complete", function()
    it("is not complete by default", function()
      assert.is_false(TranslationCache:is_complete("en"))
    end)

    it("becomes complete after mark_complete", function()
      TranslationCache:mark_complete("en")

      assert.is_true(TranslationCache:is_complete("en"))
    end)

    it("keeps different locales' completion independent", function()
      TranslationCache:mark_complete("en")

      assert.is_false(TranslationCache:is_complete("ja"))
    end)
  end)

  describe(":clear", function()
    it("resets both entries and completion flags together", function()
      TranslationCache:set("en", "iron-plate", "Iron Plate")
      TranslationCache:mark_complete("en")

      TranslationCache:clear()

      assert.is_nil(TranslationCache:get("en", "iron-plate"))
      assert.is_false(TranslationCache:is_complete("en"))
    end)
  end)
end)
