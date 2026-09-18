local RemoteCaller = require("lib.remote_caller")

describe("RemoteCaller", function()
  after_each(function()
    _G.remote = nil
  end)

  describe(":has", function()
    it("returns true when the interface exposes the named function", function()
      _G.remote = { interfaces = { ["my-mod.action"] = { is_available = true } } }

      assert.is_true(RemoteCaller:has("my-mod.action", "is_available"))
    end)

    it("returns false when the interface exists but lacks the named function", function()
      _G.remote = { interfaces = { ["my-mod.action"] = { execute = true } } }

      assert.is_false(RemoteCaller:has("my-mod.action", "is_available"))
    end)

    it("returns false when the interface is not registered", function()
      _G.remote = { interfaces = {} }

      assert.is_false(RemoteCaller:has("my-mod.action", "is_available"))
    end)
  end)

  describe(":call", function()
    it("forwards to remote.call with the interface, function name, and arguments, returning its result", function()
      local captured

      _G.remote = {
        call = function(...)
          captured = { ... }
          return "result"
        end,
      }

      local result = RemoteCaller:call("my-mod.action", "execute", "candidate", 42)

      assert.are.same({ "my-mod.action", "execute", "candidate", 42 }, captured)
      assert.are.equal("result", result)
    end)
  end)
end)
