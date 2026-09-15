local TranslatedPrototypeSource = require("lib.sources.translated_prototype_source")
local TranslationCache = require("lib.sources.translation_cache")

local function prototype(name)
  return { name = name, localised_name = {"item-name." .. name} }
end

describe("TranslatedPrototypeSource", function()
  before_each(function()
    _G.storage = {}
  end)

  after_each(function()
    _G.game = nil
  end)

  describe(":missing", function()
    it("returns prototypes without a cached translation for the locale", function()
      local source = TranslatedPrototypeSource.new("items", function()
        return { prototype("iron-plate"), prototype("copper-plate") }
      end, {"quidquid.source-items"})
      TranslationCache:set("items", "en", "iron-plate", "Iron plate")

      local missing = source:missing("en")

      assert.are.equal(1, #missing)
      assert.are.equal("copper-plate", missing[1].name)
    end)

    it("returns an empty list once every prototype is cached", function()
      local source = TranslatedPrototypeSource.new("items", function()
        return { prototype("iron-plate") }
      end, {"quidquid.source-items"})
      TranslationCache:set("items", "en", "iron-plate", "Iron plate")

      assert.are.same({}, source:missing("en"))
    end)
  end)

  describe(":remove_from_other_pending", function()
    it("removes the player from a pending locale other than the current one", function()
      local source = TranslatedPrototypeSource.new("items", function() return {} end, {"quidquid.source-items"})
      source.pending = { en = { [1] = true }, ja = { [1] = true } }

      source:remove_from_other_pending(1, "ja")

      assert.is_nil(source.pending.en)
      assert.is_true(source.pending.ja[1])
    end)

    it("leaves the current locale's pending entry untouched", function()
      local source = TranslatedPrototypeSource.new("items", function() return {} end, {"quidquid.source-items"})
      source.pending = { en = { [1] = true } }

      source:remove_from_other_pending(1, "en")

      assert.is_true(source.pending.en[1])
    end)

    it("clears a locale entirely once its last waiting player is removed", function()
      local source = TranslatedPrototypeSource.new("items", function() return {} end, {"quidquid.source-items"})
      source.pending = { en = { [1] = true } }

      source:remove_from_other_pending(1, "ja")

      assert.is_nil(source.pending.en)
    end)
  end)

  describe(":ensure_locale_progress", function()
    it("requests missing translations and marks the locale pending for a not-yet-complete locale", function()
      local requested = {}
      local source = TranslatedPrototypeSource.new("items", function()
        return { prototype("iron-plate") }
      end, {"quidquid.source-items"})
      local player = {
        index = 1,
        locale = "en",
        request_translation = function(localised_name)
          table.insert(requested, localised_name)
          return 100
        end,
      }

      source:ensure_locale_progress(player)

      assert.are.equal(1, #requested)
      assert.is_true(source.pending.en[1])
      assert.are.same({ locale = "en", name = "iron-plate" }, source.in_flight[100])
    end)

    it("does not request translations again if the locale is already pending", function()
      local request_count = 0
      local source = TranslatedPrototypeSource.new("items", function()
        return { prototype("iron-plate") }
      end, {"quidquid.source-items"})
      local player = {
        index = 1,
        locale = "en",
        request_translation = function(_localised_name)
          request_count = request_count + 1
          return 100
        end,
      }

      source:ensure_locale_progress(player)
      source:ensure_locale_progress(player)

      assert.are.equal(1, request_count)
    end)

    it("does nothing when the locale is already marked complete", function()
      TranslationCache:mark_complete("items", "en")
      local requested = false
      local source = TranslatedPrototypeSource.new("items", function()
        return { prototype("iron-plate") }
      end, {"quidquid.source-items"})
      local player = {
        index = 1,
        locale = "en",
        request_translation = function(_localised_name)
          requested = true
          return 100
        end,
      }

      source:ensure_locale_progress(player)

      assert.is_false(requested)
      assert.is_nil(source.pending.en)
    end)
  end)

  describe(":on_string_translated", function()
    it("ignores an event for an id that is not in flight", function()
      local source = TranslatedPrototypeSource.new("items", function() return {} end, {"quidquid.source-items"})

      source:on_string_translated({ id = 999, translated = true, result = "Iron plate" })

      assert.is_nil(TranslationCache:get("items", "en", "iron-plate"))
    end)

    it("caches the translated result and clears the in-flight entry", function()
      local source = TranslatedPrototypeSource.new("items", function()
        return { prototype("iron-plate"), prototype("copper-plate") }
      end, {"quidquid.source-items"})
      source.in_flight[100] = { locale = "en", name = "iron-plate" }

      source:on_string_translated({ id = 100, translated = true, result = "Iron plate" })

      assert.are.equal("Iron plate", TranslationCache:get("items", "en", "iron-plate"))
      assert.is_nil(source.in_flight[100])
    end)

    it("caches false when translation failed", function()
      local source = TranslatedPrototypeSource.new("items", function()
        return { prototype("iron-plate"), prototype("copper-plate") }
      end, {"quidquid.source-items"})
      source.in_flight[100] = { locale = "en", name = "iron-plate" }

      source:on_string_translated({ id = 100, translated = false })

      assert.is_false(TranslationCache:get("items", "en", "iron-plate"))
    end)

    it("marks the locale complete and notifies every waiting player once all prototypes are translated", function()
      local printed = {}
      local source = TranslatedPrototypeSource.new("items", function()
        return { prototype("iron-plate") }
      end, {"quidquid.source-items"})
      source.in_flight[100] = { locale = "en", name = "iron-plate" }
      source.pending.en = { [1] = true, [2] = true }
      _G.game = {
        get_player = function(index)
          return {
            index = index,
            print = function(message)
              table.insert(printed, { index = index, message = message })
            end,
          }
        end,
      }

      source:on_string_translated({ id = 100, translated = true, result = "Iron plate" })

      assert.is_true(TranslationCache:is_complete("items", "en"))
      assert.is_nil(source.pending.en)
      assert.are.equal(2, #printed)
    end)
  end)

  describe(":on_player_left_game", function()
    it("removes the player from pending without promoting anyone when no one else is waiting", function()
      local source = TranslatedPrototypeSource.new("items", function() return {} end, {"quidquid.source-items"})
      source.pending.en = { [1] = true }

      source:on_player_left_game({ player_index = 1 })

      assert.is_nil(source.pending.en)
    end)

    it("promotes the next waiting player as translation requester when one remains", function()
      local requested_by
      local source = TranslatedPrototypeSource.new("items", function()
        return { prototype("iron-plate") }
      end, {"quidquid.source-items"})
      source.pending.en = { [1] = true, [2] = true }
      _G.game = {
        get_player = function(index)
          return {
            index = index,
            locale = "en",
            request_translation = function(_localised_name)
              requested_by = index
              return 100
            end,
          }
        end,
      }

      source:on_player_left_game({ player_index = 1 })

      assert.is_true(source.pending.en[2])
      assert.is_nil(source.pending.en[1])
      assert.are.equal(2, requested_by)
    end)
  end)

  describe(":on_configuration_changed", function()
    it("clears the translation cache and in-flight/pending state", function()
      TranslationCache:set("items", "en", "iron-plate", "Iron plate")
      TranslationCache:mark_complete("items", "en")
      local source = TranslatedPrototypeSource.new("items", function() return {} end, {"quidquid.source-items"})
      source.in_flight[100] = { locale = "en", name = "iron-plate" }
      source.pending.en = { [1] = true }
      _G.game = { players = {} }

      source:on_configuration_changed()

      assert.is_nil(TranslationCache:get("items", "en", "iron-plate"))
      assert.is_false(TranslationCache:is_complete("items", "en"))
      assert.are.same({}, source.in_flight)
      assert.are.same({}, source.pending)
    end)
  end)
end)
