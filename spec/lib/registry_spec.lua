local Registry = require("lib.registry")

local function spy_logger()
  local messages = {}
  local logger = function(message)
    table.insert(messages, message)
  end
  return logger, messages
end

local function always_true_caller()
  return {
    has = function() return false end,
    call = function() error("should not be called") end,
  }
end

local function caller_with_is_applicable(result)
  return {
    has = function(_, _, function_name)
      return function_name == "is_applicable"
    end,
    call = function(_, _, _, ...)
      return result
    end,
  }
end

describe("Registry", function()
  describe(":register_source", function()
    it("accepts a definition with the current contract version", function()
      local registry = Registry.new()

      local ok = registry:register_source({
        version = 1,
        id = "items",
        prefixes = {"i", "item"},
        interface = "my-mod.source-items",
      })

      assert.is_true(ok)
    end)

    it("rejects a definition with an unsupported contract version", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger)

      local ok = registry:register_source({
        version = 2,
        id = "items",
        prefixes = {"i"},
        interface = "my-mod.source-items",
      })

      assert.is_false(ok)
      assert.are.equal(1, #messages)
    end)

    it("keeps the first registration when two sources claim the same prefix", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger)

      registry:register_source({
        version = 1,
        id = "items",
        prefixes = {"i"},
        interface = "my-mod.source-items",
      })
      registry:register_source({
        version = 1,
        id = "recipes",
        prefixes = {"i"},
        interface = "my-mod.source-recipes",
      })

      assert.are.equal(1, #messages)
    end)
  end)

  describe(":register_action", function()
    it("accepts a definition with the current contract version", function()
      local registry = Registry.new()

      local ok = registry:register_action({
        version = 1,
        id = "logistics-request",
        types = {"item"},
        key = "confirm",
        interface = "my-mod.action-logistics-request",
      })

      assert.is_true(ok)
    end)

    it("rejects a definition with an unsupported contract version", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger)

      local ok = registry:register_action({
        version = 2,
        id = "logistics-request",
        types = {"item"},
        key = "confirm",
        interface = "my-mod.action-logistics-request",
      })

      assert.is_false(ok)
      assert.are.equal(1, #messages)
    end)

    it("rejects a definition with no key", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger)

      local ok = registry:register_action({
        version = 1,
        id = "logistics-request",
        types = {"item"},
        interface = "my-mod.action-logistics-request",
      })

      assert.is_false(ok)
      assert.are.equal(1, #messages)
    end)

    it("rejects a definition with no types", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger)

      local ok = registry:register_action({
        version = 1,
        id = "logistics-request",
        key = "confirm",
        interface = "my-mod.action-logistics-request",
      })

      assert.is_false(ok)
      assert.are.equal(1, #messages)
    end)
  end)

  describe(":resolve_actions", function()
    it("returns nothing for a type with no registered actions", function()
      local registry = Registry.new()

      local resolved = registry:resolve_actions({type = "item", id = "iron-plate"}, 1, always_true_caller())

      assert.are.same({}, resolved)
    end)

    it("returns an action bound to a type under its registered key", function()
      local registry = Registry.new()
      registry:register_action({
        version = 1,
        id = "logistics-request",
        types = {"item"},
        key = "confirm",
        interface = "my-mod.action-logistics-request",
      })

      local resolved = registry:resolve_actions({type = "item", id = "iron-plate"}, 1, always_true_caller())

      assert.are.equal("logistics-request", resolved["confirm"].id)
    end)

    it("keeps the first action when two actions claim the same key for the same type", function()
      local logger, messages = spy_logger()
      local registry = Registry.new(logger)
      registry:register_action({
        version = 1, id = "logistics-request", types = {"item"}, key = "confirm",
        interface = "my-mod.action-logistics-request",
      })
      registry:register_action({
        version = 1, id = "duplicate", types = {"item"}, key = "confirm",
        interface = "my-mod.action-duplicate",
      })

      local resolved = registry:resolve_actions({type = "item", id = "iron-plate"}, 1, always_true_caller())

      assert.are.equal("logistics-request", resolved["confirm"].id)
      assert.are.equal(1, #messages)
    end)

    it("does not let a key collision on one type affect another type", function()
      local registry = Registry.new()
      registry:register_action({
        version = 1, id = "logistics-request", types = {"item"}, key = "confirm",
        interface = "my-mod.action-logistics-request",
      })
      registry:register_action({
        version = 1, id = "add-to-crafting-queue", types = {"fluid"}, key = "confirm",
        interface = "my-mod.action-crafting-queue",
      })

      local item_resolved = registry:resolve_actions({type = "item", id = "iron-plate"}, 1, always_true_caller())
      local fluid_resolved = registry:resolve_actions({type = "fluid", id = "water"}, 1, always_true_caller())

      assert.are.equal("logistics-request", item_resolved["confirm"].id)
      assert.are.equal("add-to-crafting-queue", fluid_resolved["confirm"].id)
    end)

    it("omits an action whose is_applicable returns false", function()
      local registry = Registry.new()
      registry:register_action({
        version = 1, id = "logistics-request", types = {"item"}, key = "confirm",
        interface = "my-mod.action-logistics-request",
      })

      local resolved = registry:resolve_actions({type = "item", id = "iron-plate"}, 1, caller_with_is_applicable(false))

      assert.is_nil(resolved["confirm"])
    end)

    it("includes an action that has no is_applicable implementation", function()
      local registry = Registry.new()
      registry:register_action({
        version = 1, id = "logistics-request", types = {"item"}, key = "confirm",
        interface = "my-mod.action-logistics-request",
      })

      local resolved = registry:resolve_actions({type = "item", id = "iron-plate"}, 1, always_true_caller())

      assert.are.equal("logistics-request", resolved["confirm"].id)
    end)
  end)
end)
