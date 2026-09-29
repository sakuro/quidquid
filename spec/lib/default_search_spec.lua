local DefaultSearch = require("lib.default_search")

describe("DefaultSearch", function()
  describe(".setting_name", function()
    it("appends -default-search to the declaration name", function()
      assert.are.equal("my-mod-widgets-default-search", DefaultSearch.setting_name("my-mod-widgets"))
    end)
  end)

  describe(".ALWAYS", function()
    it("lists Quidquid's own item, fluid, recipe and technology sources", function()
      assert.is_true(DefaultSearch.ALWAYS["quidquid-items"])
      assert.is_true(DefaultSearch.ALWAYS["quidquid-fluids"])
      assert.is_true(DefaultSearch.ALWAYS["quidquid-recipes"])
      assert.is_true(DefaultSearch.ALWAYS["quidquid-technologies"])
    end)

    it("does not list the calculator", function()
      assert.is_nil(DefaultSearch.ALWAYS["quidquid-calculator"])
    end)
  end)

  describe(".runtime.classify", function()
    after_each(function()
      _G.prototypes = nil
    end)

    it("returns nil when no setting of that name exists", function()
      _G.prototypes = { mod_setting = {} }

      assert.is_nil(DefaultSearch.runtime.classify("my-mod-widgets-default-search"))
    end)

    it("returns 'ok' for a runtime-per-user bool-setting", function()
      _G.prototypes = {
        mod_setting = {
          ["my-mod-widgets-default-search"] = { type = "bool-setting", setting_type = "runtime-per-user" },
        },
      }

      assert.are.equal("ok", DefaultSearch.runtime.classify("my-mod-widgets-default-search"))
    end)

    it("returns 'invalid' for a bool-setting of another setting_type", function()
      _G.prototypes = {
        mod_setting = {
          ["my-mod-widgets-default-search"] = { type = "bool-setting", setting_type = "startup" },
        },
      }

      assert.are.equal("invalid", DefaultSearch.runtime.classify("my-mod-widgets-default-search"))
    end)

    it("returns 'invalid' for a runtime-per-user setting of another type", function()
      _G.prototypes = {
        mod_setting = {
          ["my-mod-widgets-default-search"] = { type = "string-setting", setting_type = "runtime-per-user" },
        },
      }

      assert.are.equal("invalid", DefaultSearch.runtime.classify("my-mod-widgets-default-search"))
    end)
  end)

  describe(".runtime.enabled", function()
    after_each(function()
      _G.game = nil
    end)

    it("returns true when the player's setting value is true", function()
      _G.game = {
        get_player = function()
          return { mod_settings = { ["my-mod-widgets-default-search"] = { value = true } } }
        end,
      }

      assert.is_true(DefaultSearch.runtime.enabled(1, "my-mod-widgets-default-search"))
    end)

    it("returns false when the player's setting value is false", function()
      _G.game = {
        get_player = function()
          return { mod_settings = { ["my-mod-widgets-default-search"] = { value = false } } }
        end,
      }

      assert.is_false(DefaultSearch.runtime.enabled(1, "my-mod-widgets-default-search"))
    end)

    it("returns false when the player no longer exists", function()
      _G.game = {
        get_player = function()
          return nil
        end,
      }

      assert.is_false(DefaultSearch.runtime.enabled(1, "my-mod-widgets-default-search"))
    end)
  end)
end)
