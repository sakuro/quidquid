local ActionMessage = require("lib.action_message")

describe("ActionMessage", function()
  local candidate = { icon = "item/iron-plate", label = "Iron plate" }

  describe(".localise", function()
    it("puts the icon and label before a bare key", function()
      assert.are.same(
        { "my-mod.done", "[img=item/iron-plate]", "Iron plate" },
        (ActionMessage.localise(candidate, { "my-mod.done" }))
      )
    end)

    it("appends the message's own parameters after the icon and label", function()
      assert.are.same(
        { "my-mod.done", "[img=item/iron-plate]", "Iron plate", "a", { "item-name.coal" } },
        (ActionMessage.localise(candidate, { "my-mod.done", "a", { "item-name.coal" } }))
      )
    end)

    it("accepts exactly the maximum number of parameters", function()
      local message = { "my-mod.done" }
      for i = 1, ActionMessage.MAX_PARAMETERS do
        message[i + 1] = tostring(i)
      end

      local localised = ActionMessage.localise(candidate, message)

      assert.are.equal(ActionMessage.MAX_PARAMETERS + 3, #localised)
    end)

    it("rejects one parameter over the maximum", function()
      local message = { "my-mod.done" }
      for i = 1, ActionMessage.MAX_PARAMETERS + 1 do
        message[i + 1] = tostring(i)
      end

      local localised, reason = ActionMessage.localise(candidate, message)

      assert.is_nil(localised)
      assert.is_string(reason)
    end)

    it("rejects a value that is not a table", function()
      local localised, reason = ActionMessage.localise(candidate, "my-mod.done")

      assert.is_nil(localised)
      assert.is_string(reason)
    end)

    it("rejects a table whose first element is not a string", function()
      local localised, reason = ActionMessage.localise(candidate, { { "my-mod.done" } })

      assert.is_nil(localised)
      assert.is_string(reason)
    end)

    it("pins the parameter limit to the LocalisedString limit less the icon and label", function()
      assert.are.equal(18, ActionMessage.MAX_PARAMETERS)
    end)
  end)
end)
