local Registry = require("lib.registry")

local function spy_logger()
  local messages = {}
  local logger = function(message)
    table.insert(messages, message)
  end
  return logger, messages
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
end)
