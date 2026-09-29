local ActionRunner = require("lib.action_runner")

describe("ActionRunner", function()
  local player

  before_each(function()
    player = {
      create_local_flying_text = function()
        error("ActionRunner must not show flying text itself")
      end,
    }
    _G.game = {
      get_player = function(_player_index)
        return player
      end,
    }
  end)

  after_each(function()
    _G.game = nil
  end)

  local candidate = { label = "Iron plate", icon = "item/iron-plate" }

  describe(".run", function()
    it("does nothing when the player no longer exists", function()
      _G.game.get_player = function(_player_index)
        return nil
      end
      local applied = false

      local message = ActionRunner.run(candidate, 1, function(_candidate, _player)
        return "payload", nil
      end, function(_payload, _candidate, _player)
        applied = true
      end)

      assert.is_false(applied)
      assert.is_nil(message)
    end)

    it("applies the payload and returns what apply_fn returns", function()
      local applied_payload, applied_candidate, applied_player

      local message = ActionRunner.run(candidate, 1, function(_candidate, _player)
        return "recipe-token", nil
      end, function(payload, resolved_candidate, resolved_player)
        applied_payload = payload
        applied_candidate = resolved_candidate
        applied_player = resolved_player
        return { "quidquid.action-research-queue-added" }
      end)

      assert.are.equal("recipe-token", applied_payload)
      assert.are.equal(candidate, applied_candidate)
      assert.are.equal(player, applied_player)
      assert.are.same({ "quidquid.action-research-queue-added" }, message)
    end)

    it("returns nil on success when apply_fn returns nothing", function()
      local message = ActionRunner.run(candidate, 1, function(_candidate, _player)
        return "payload", nil
      end, function(_payload, _candidate, _player) end)

      assert.is_nil(message)
    end)

    it("returns the resolved locale key and does not apply when the payload is nil", function()
      local applied = false

      local message = ActionRunner.run(candidate, 1, function(_candidate, _player)
        return nil, "quidquid.action-craft-no-recipe"
      end, function(_payload, _candidate, _player)
        applied = true
      end)

      assert.is_false(applied)
      assert.are.same({ "quidquid.action-craft-no-recipe" }, message)
    end)

    it("returns nil when the payload and locale key are both nil and there is no fallback", function()
      local message = ActionRunner.run(candidate, 1, function(_candidate, _player)
        return nil, nil
      end, function(_payload, _candidate, _player) end)

      assert.is_nil(message)
    end)

    it("falls back to the fallback locale key when the payload and locale key are both nil", function()
      local message = ActionRunner.run(candidate, 1, function(_candidate, _player)
        return nil, nil
      end, function(_payload, _candidate, _player) end, "quidquid.action-open-factoriopedia-unavailable")

      assert.are.same({ "quidquid.action-open-factoriopedia-unavailable" }, message)
    end)

    it("prefers the resolved locale key over the fallback locale key", function()
      local message = ActionRunner.run(candidate, 1, function(_candidate, _player)
        return nil, "quidquid.action-craft-no-recipe"
      end, function(_payload, _candidate, _player) end, "quidquid.action-open-factoriopedia-unavailable")

      assert.are.same({ "quidquid.action-craft-no-recipe" }, message)
    end)
  end)
end)
