local Declarations = require("lib.declarations")
local Registry = require("lib.registry")

local CONTRACT_VERSION = Declarations.CONTRACT_VERSION
local OTHER_CONTRACT_VERSION = CONTRACT_VERSION - 1

local function spy_logger()
  local messages = {}
  local logger = function(message)
    table.insert(messages, message)
  end
  return logger, messages
end

-- The default: every source has a valid, always-on default-search setting. A test
-- about registration itself, rather than about default-search membership, wants
-- register_source to succeed without caring how; override classify/enabled only
-- when the default-search behavior is what's under test.
local function settings_stub(overrides)
  overrides = overrides or {}
  return {
    classify = overrides.classify or function(_)
      return "ok"
    end,
    enabled = overrides.enabled or function(_, _)
      return true
    end,
  }
end

local function always_true_caller()
  return {
    has = function()
      return false
    end,
    call = function()
      error("should not be called")
    end,
  }
end

local function caller_with_is_available(result)
  return {
    has = function(_, _, function_name)
      return function_name == "is_available"
    end,
    call = function(_, _, _)
      return result
    end,
  }
end

local function caller_with_throwing_is_available(error_message)
  return {
    has = function(_, _, function_name)
      return function_name == "is_available"
    end,
    call = function(_, _, _)
      error(error_message)
    end,
  }
end

describe("Registry", function()
  describe(":register_source", function()
    it("accepts a definition with the current contract version", function()
      local registry = Registry.new(nil, settings_stub())

      local ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items",
        type = "item",
        prefixes = { "i", "item" },
        interface = "my-mod.source-items",
      })

      assert.is_true(ok)
    end)

    it("rejects a definition with an unsupported contract version", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger, settings_stub())

      local ok = registry:register_source({
        contract_version = OTHER_CONTRACT_VERSION,
        id = "items",
        type = "item",
        prefixes = { "i" },
        interface = "my-mod.source-items",
      })

      assert.is_false(ok)
      assert.are.equal(1, #messages)
    end)

    it("rejects a definition with no type", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger, settings_stub())

      local ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items",
        prefixes = { "i" },
        interface = "my-mod.source-items",
      })

      assert.is_false(ok)
      assert.are.equal(1, #messages)
    end)

    it("keeps the first registration when two sources claim the same prefix", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger, settings_stub())

      registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items",
        type = "item",
        prefixes = { "i" },
        interface = "my-mod.source-items",
      })
      registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "recipes",
        type = "recipe",
        prefixes = { "i" },
        interface = "my-mod.source-recipes",
      })

      assert.are.equal(1, #messages)
    end)

    it("rejects a second source claiming an already-registered type, keeping the first", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger, settings_stub())

      local first_ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items",
        type = "item",
        prefixes = { "i" },
        interface = "my-mod.source-items",
      })
      local second_ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "duplicate-items",
        type = "item",
        prefixes = { "d" },
        interface = "my-mod.source-duplicate-items",
      })

      assert.is_true(first_ok)
      assert.is_false(second_ok)
      assert.are.equal(1, #messages)

      local default_sources = registry:default_search_sources(1)
      assert.are.equal(1, #default_sources)
      assert.are.equal("items", default_sources[1].id)
    end)

    it("allows two sources to register for different types", function()
      local registry = Registry.new(nil, settings_stub())

      local item_ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items",
        type = "item",
        prefixes = { "i" },
        interface = "my-mod.source-items",
      })
      local fluid_ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "fluids",
        type = "fluid",
        prefixes = { "f" },
        interface = "my-mod.source-fluids",
      })

      assert.is_true(item_ok)
      assert.is_true(fluid_ok)
    end)

    it("treats prefixes differing only in case as distinct", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger, settings_stub())

      local recipe_ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "recipes",
        type = "recipe",
        prefixes = { "r" },
        interface = "my-mod.source-recipes",
      })
      local resource_ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "resources",
        type = "resource",
        prefixes = { "R" },
        interface = "my-mod.source-resources",
      })

      assert.is_true(recipe_ok)
      assert.is_true(resource_ok)
      assert.are.same({}, messages)
      assert.are.equal("recipes", registry:source_for_prefix("r").id)
      assert.are.equal("resources", registry:source_for_prefix("R").id)
    end)

    it("ignores an empty-string prefix but still registers the source and its other prefixes", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger, settings_stub())

      local ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items",
        type = "item",
        prefixes = { "i", "" },
        interface = "my-mod.source-items",
      })

      assert.is_true(ok)
      assert.are.equal(1, #messages)
      assert.is_nil(registry:source_for_prefix(""))
      assert.are.equal("items", registry:source_for_prefix("i").id)
    end)
  end)

  describe(":source_for_prefix", function()
    it("returns the source definition registered for a prefix", function()
      local registry = Registry.new(nil, settings_stub())
      registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items",
        type = "item",
        prefixes = { "i", "item" },
        interface = "my-mod.source-items",
      })

      local source = registry:source_for_prefix("item")

      assert.are.equal("items", source.id)
    end)

    it("does not match a prefix typed in another case", function()
      local registry = Registry.new(nil, settings_stub())
      registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items",
        type = "item",
        prefixes = { "i", "item" },
        interface = "my-mod.source-items",
      })

      assert.is_nil(registry:source_for_prefix("I"))
      assert.is_nil(registry:source_for_prefix("Item"))
    end)

    it("returns nil for an unregistered prefix", function()
      local registry = Registry.new(nil, settings_stub())

      assert.is_nil(registry:source_for_prefix("nope"))
    end)
  end)

  describe(":source_by_id", function()
    it("returns the source definition registered under an id", function()
      local registry = Registry.new(nil, settings_stub())
      registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items",
        type = "item",
        prefixes = { "i" },
        interface = "my-mod.source-items",
      })

      local source = registry:source_by_id("items")

      assert.are.equal("items", source.id)
    end)

    it("returns nil for an unknown id", function()
      local registry = Registry.new(nil, settings_stub())

      assert.is_nil(registry:source_by_id("nope"))
    end)

    it("returns nil for a nil id", function()
      local registry = Registry.new(nil, settings_stub())

      assert.is_nil(registry:source_by_id(nil))
    end)
  end)

  describe(":register_action", function()
    it("accepts a definition with the current contract version", function()
      local registry = Registry.new()

      local ok = registry:register_action({
        contract_version = CONTRACT_VERSION,
        id = "logistics-request",
        types = { "item" },
        input_name = "confirm",
        interface = "my-mod.action-logistics-request",
      })

      assert.is_true(ok)
    end)

    it("rejects a definition with an unsupported contract version", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger)

      local ok = registry:register_action({
        contract_version = OTHER_CONTRACT_VERSION,
        id = "logistics-request",
        types = { "item" },
        input_name = "confirm",
        interface = "my-mod.action-logistics-request",
      })

      assert.is_false(ok)
      assert.are.equal(1, #messages)
    end)

    it("rejects a definition with no input_name", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger)

      local ok = registry:register_action({
        contract_version = CONTRACT_VERSION,
        id = "logistics-request",
        types = { "item" },
        interface = "my-mod.action-logistics-request",
      })

      assert.is_false(ok)
      assert.are.equal(1, #messages)
    end)

    it("rejects a definition with no types", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger)

      local ok = registry:register_action({
        contract_version = CONTRACT_VERSION,
        id = "logistics-request",
        input_name = "confirm",
        interface = "my-mod.action-logistics-request",
      })

      assert.is_false(ok)
      assert.are.equal(1, #messages)
    end)
  end)

  describe(":default_search_sources", function()
    it("always includes one of Quidquid's own fixed sources, without consulting settings", function()
      local registry = Registry.new(
        nil,
        settings_stub({
          classify = function()
            error("classify should not be called for a fixed member")
          end,
        })
      )
      registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "quidquid-items",
        type = "item",
        prefixes = { "i" },
        interface = "quidquid.item-source",
      })

      local default_sources = registry:default_search_sources(1)

      assert.are.equal(1, #default_sources)
      assert.are.equal("quidquid-items", default_sources[1].id)
    end)

    it("includes an extension source only for a player whose default-search setting is enabled", function()
      local enabled_for = { [1] = true, [2] = false }
      local registry = Registry.new(
        nil,
        settings_stub({
          enabled = function(player_index, name)
            assert.are.equal("items-default-search", name)
            return enabled_for[player_index] == true
          end,
        })
      )
      registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items",
        type = "item",
        prefixes = { "i" },
        interface = "my-mod.source-items",
      })

      assert.are.equal(1, #registry:default_search_sources(1))
      assert.are.same({}, registry:default_search_sources(2))
    end)

    it("rejects a source whose default-search setting is not a runtime-per-user bool-setting", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(
        logger,
        settings_stub({
          classify = function(name)
            if name == "items-default-search" then
              return "invalid"
            end
            return "ok"
          end,
        })
      )

      local ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items",
        type = "item",
        prefixes = { "i" },
        interface = "my-mod.source-items",
      })

      assert.is_false(ok)
      assert.are.same({
        "quidquid: source 'items' rejected: setting 'items-default-search' must be a runtime-per-user bool-setting",
      }, messages)
      assert.is_nil(registry:source_for_prefix("i"))
      assert.is_nil(registry:source_by_id("items"))

      -- Same type, same prefix: proves the rejected registration claimed neither.
      local retry_ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items-again",
        type = "item",
        prefixes = { "i" },
        interface = "my-mod.source-items",
      })
      assert.is_true(retry_ok)
      assert.are.equal("items-again", registry:source_for_prefix("i").id)
    end)

    it("rejects a source with neither prefixes nor a default-search setting", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(
        logger,
        settings_stub({
          classify = function()
            return nil
          end,
        })
      )

      local ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items",
        type = "item",
        interface = "my-mod.source-items",
      })

      assert.is_false(ok)
      assert.are.same({
        "quidquid: source 'items' rejected: unreachable: none of its prefixes could be claimed and it has "
          .. "no 'items-default-search' setting",
      }, messages)
      assert.is_nil(registry:source_by_id("items"))

      -- Same id, same type: proves the rejected registration did not claim the type.
      local retry_ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items",
        type = "item",
        prefixes = { "i" },
        interface = "my-mod.source-items",
      })
      assert.is_true(retry_ok)
      assert.are.equal("items", registry:source_for_prefix("i").id)
    end)

    it(
      "rejects a source as unreachable when all its declared prefixes are already taken and it has no setting",
      function()
        local logger, messages = spy_logger()
        local registry = Registry.new(
          logger,
          settings_stub({
            classify = function()
              return nil
            end,
          })
        )
        registry:register_source({
          contract_version = CONTRACT_VERSION,
          id = "items",
          type = "item",
          prefixes = { "i" },
          interface = "my-mod.source-items",
        })

        local ok = registry:register_source({
          contract_version = CONTRACT_VERSION,
          id = "other-items",
          type = "resource",
          prefixes = { "i" },
          interface = "my-mod.source-other-items",
        })

        assert.is_false(ok)
        assert.are.same({
          "quidquid: source 'other-items' prefix 'i' ignored: already registered by 'items'",
          "quidquid: source 'other-items' rejected: unreachable: none of its prefixes could be claimed and it "
            .. "has no 'other-items-default-search' setting",
        }, messages)
        assert.is_nil(registry:source_by_id("other-items"))
        assert.are.equal("items", registry:source_for_prefix("i").id)

        -- Same id, same type, a prefix nobody holds: proves nothing was claimed.
        local retry_ok = registry:register_source({
          contract_version = CONTRACT_VERSION,
          id = "other-items",
          type = "resource",
          prefixes = { "j" },
          interface = "my-mod.source-other-items",
        })
        assert.is_true(retry_ok)
        assert.are.equal("other-items", registry:source_for_prefix("j").id)
      end
    )

    it("rejects a source as unreachable when its only prefix is empty and it has no setting", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(
        logger,
        settings_stub({
          classify = function()
            return nil
          end,
        })
      )

      local ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items",
        type = "item",
        prefixes = { "" },
        interface = "my-mod.source-items",
      })

      assert.is_false(ok)
      assert.are.same({
        "quidquid: source 'items' prefix '' ignored: empty prefixes are not allowed",
        "quidquid: source 'items' rejected: unreachable: none of its prefixes could be claimed and it has "
          .. "no 'items-default-search' setting",
      }, messages)
      assert.is_nil(registry:source_by_id("items"))

      local retry_ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items",
        type = "item",
        prefixes = { "i" },
        interface = "my-mod.source-items",
      })
      assert.is_true(retry_ok)
      assert.are.equal("items", registry:source_for_prefix("i").id)
    end)

    it(
      "registers a source whose declared prefixes are all taken when it has an enabled default-search setting",
      function()
        local registry = Registry.new(nil, settings_stub())
        registry:register_source({
          contract_version = CONTRACT_VERSION,
          id = "items",
          type = "item",
          prefixes = { "i" },
          interface = "my-mod.source-items",
        })

        local ok = registry:register_source({
          contract_version = CONTRACT_VERSION,
          id = "other-items",
          type = "resource",
          prefixes = { "i" },
          interface = "my-mod.source-other-items",
        })

        assert.is_true(ok)
        assert.are.equal("items", registry:source_for_prefix("i").id)
        local default_sources = registry:default_search_sources(1)
        assert.are.equal(2, #default_sources)
        assert.are.equal("other-items", default_sources[2].id)
      end
    )

    it("rejects the fixed-false calculator as unreachable when its prefix is already taken", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(
        logger,
        settings_stub({
          classify = function(name)
            if name == "quidquid-calculator-default-search" then
              error("classify should not be called for a fixed member")
            end
            return "ok"
          end,
        })
      )
      registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "equals-recipes",
        type = "recipe",
        prefixes = { "=" },
        interface = "my-mod.source-equals-recipes",
      })

      local ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "quidquid-calculator",
        type = "calculation",
        prefixes = { "=" },
        interface = "quidquid.calculator-source",
      })

      assert.is_false(ok)
      assert.are.same({
        "quidquid: source 'quidquid-calculator' prefix '=' ignored: already registered by 'equals-recipes'",
        "quidquid: source 'quidquid-calculator' rejected: unreachable: none of its prefixes could be claimed",
      }, messages)
      assert.is_nil(registry:source_by_id("quidquid-calculator"))
    end)

    it(
      "never calls classify or enabled for the fixed-false calculator, and never includes it in the default search",
      function()
        local registry = Registry.new(
          nil,
          settings_stub({
            classify = function()
              error("classify should not be called for a fixed member")
            end,
            enabled = function()
              error("enabled should not be called for a fixed member")
            end,
          })
        )
        registry:register_source({
          contract_version = CONTRACT_VERSION,
          id = "quidquid-calculator",
          type = "calculation",
          prefixes = { "=" },
          interface = "quidquid.calculator-source",
        })

        assert.are.same({}, registry:default_search_sources(1))
      end
    )

    it("counts a prefix repeated within one declaration only once, without logging it as taken", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger, settings_stub())

      local ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items",
        type = "item",
        prefixes = { "i", "i" },
        interface = "my-mod.source-items",
      })

      assert.is_true(ok)
      assert.are.same({}, messages)
      assert.are.equal("items", registry:source_for_prefix("i").id)
    end)

    it("registers a source with no setting but with prefixes, and never includes it in the default search", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(
        logger,
        settings_stub({
          classify = function()
            return nil
          end,
        })
      )

      local ok = registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "calculator",
        type = "calculation",
        prefixes = { "=" },
        interface = "my-mod.source-calculator",
      })

      assert.is_true(ok)
      assert.are.same({}, messages)
      assert.are.equal("calculator", registry:source_for_prefix("=").id)
      assert.are.same({}, registry:default_search_sources(1))
    end)

    it("returns sources in registration order", function()
      local registry = Registry.new(nil, settings_stub())
      registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "recipes",
        type = "recipe",
        prefixes = { "r" },
        interface = "my-mod.source-recipes",
      })
      registry:register_source({
        contract_version = CONTRACT_VERSION,
        id = "items",
        type = "item",
        prefixes = { "i" },
        interface = "my-mod.source-items",
      })

      local default_sources = registry:default_search_sources(1)

      assert.are.equal(2, #default_sources)
      assert.are.equal("recipes", default_sources[1].id)
      assert.are.equal("items", default_sources[2].id)
    end)

    it("returns an empty list when no sources are registered", function()
      local registry = Registry.new(nil, settings_stub())

      local default_sources = registry:default_search_sources(1)

      assert.are.same({}, default_sources)
    end)
  end)

  describe(":resolve_actions", function()
    it("returns nothing for a type with no registered actions", function()
      local registry = Registry.new()

      local resolved = registry:resolve_actions({ type = "item", id = "iron-plate" }, 1, always_true_caller())

      assert.are.same({}, resolved)
    end)

    it("returns an action bound to a type under its registered input_name", function()
      local registry = Registry.new()
      registry:register_action({
        contract_version = CONTRACT_VERSION,
        id = "logistics-request",
        types = { "item" },
        input_name = "confirm",
        interface = "my-mod.action-logistics-request",
      })

      local resolved = registry:resolve_actions({ type = "item", id = "iron-plate" }, 1, always_true_caller())

      assert.are.equal("logistics-request", resolved["confirm"].id)
    end)

    it("keeps the first action when two actions claim the same input_name for the same type", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger)
      registry:register_action({
        contract_version = CONTRACT_VERSION,
        id = "logistics-request",
        types = { "item" },
        input_name = "confirm",
        interface = "my-mod.action-logistics-request",
      })
      registry:register_action({
        contract_version = CONTRACT_VERSION,
        id = "duplicate",
        types = { "item" },
        input_name = "confirm",
        interface = "my-mod.action-duplicate",
      })

      local resolved = registry:resolve_actions({ type = "item", id = "iron-plate" }, 1, always_true_caller())

      assert.are.equal("logistics-request", resolved["confirm"].id)
      assert.are.equal(1, #messages)
    end)

    it("does not let an input_name collision on one type affect another type", function()
      local registry = Registry.new()
      registry:register_action({
        contract_version = CONTRACT_VERSION,
        id = "logistics-request",
        types = { "item" },
        input_name = "confirm",
        interface = "my-mod.action-logistics-request",
      })
      registry:register_action({
        contract_version = CONTRACT_VERSION,
        id = "add-to-crafting-queue",
        types = { "fluid" },
        input_name = "confirm",
        interface = "my-mod.action-crafting-queue",
      })

      local item_resolved = registry:resolve_actions({ type = "item", id = "iron-plate" }, 1, always_true_caller())
      local fluid_resolved = registry:resolve_actions({ type = "fluid", id = "water" }, 1, always_true_caller())

      assert.are.equal("logistics-request", item_resolved["confirm"].id)
      assert.are.equal("add-to-crafting-queue", fluid_resolved["confirm"].id)
    end)

    it("omits an action whose is_available returns false", function()
      local registry = Registry.new()
      registry:register_action({
        contract_version = CONTRACT_VERSION,
        id = "logistics-request",
        types = { "item" },
        input_name = "confirm",
        interface = "my-mod.action-logistics-request",
      })

      local resolved =
        registry:resolve_actions({ type = "item", id = "iron-plate" }, 1, caller_with_is_available(false))

      assert.is_nil(resolved["confirm"])
    end)

    it("includes an action that has no is_available implementation", function()
      local registry = Registry.new()
      registry:register_action({
        contract_version = CONTRACT_VERSION,
        id = "logistics-request",
        types = { "item" },
        input_name = "confirm",
        interface = "my-mod.action-logistics-request",
      })

      local resolved = registry:resolve_actions({ type = "item", id = "iron-plate" }, 1, always_true_caller())

      assert.are.equal("logistics-request", resolved["confirm"].id)
    end)

    it("omits an action whose is_available check throws, and logs the failure", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger)
      registry:register_action({
        contract_version = CONTRACT_VERSION,
        id = "logistics-request",
        types = { "item" },
        input_name = "confirm",
        interface = "my-mod.action-logistics-request",
      })

      local resolved =
        registry:resolve_actions({ type = "item", id = "iron-plate" }, 1, caller_with_throwing_is_available("boom"))

      assert.is_nil(resolved["confirm"])
      assert.are.equal(1, #messages)
    end)
  end)
end)
