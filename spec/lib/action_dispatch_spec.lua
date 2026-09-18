local ActionDispatch = require("lib.action_dispatch")

describe("ActionDispatch", function()
  local flying_texts
  local player

  before_each(function()
    flying_texts = {}
    player = {
      create_local_flying_text = function(params)
        table.insert(flying_texts, params)
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

      ActionDispatch.run(candidate, 1, function(_candidate, _player)
        return "payload", nil
      end, function(_payload, _candidate, _player)
        applied = true
      end)

      assert.is_false(applied)
      assert.are.same({}, flying_texts)
    end)

    it("applies the payload and shows no message on success", function()
      local applied_payload, applied_candidate, applied_player

      ActionDispatch.run(candidate, 1, function(_candidate, _player)
        return "recipe-token", nil
      end, function(payload, resolved_candidate, resolved_player)
        applied_payload = payload
        applied_candidate = resolved_candidate
        applied_player = resolved_player
      end)

      assert.are.equal("recipe-token", applied_payload)
      assert.are.equal(candidate, applied_candidate)
      assert.are.equal(player, applied_player)
      assert.are.same({}, flying_texts)
    end)

    it("shows the resolved key and does not apply when the payload is nil", function()
      local applied = false

      ActionDispatch.run(candidate, 1, function(_candidate, _player)
        return nil, "quidquid.action-craft-no-recipe"
      end, function(_payload, _candidate, _player)
        applied = true
      end)

      assert.is_false(applied)
      assert.are.same({
        {
          text = { "quidquid.action-craft-no-recipe", "[img=item/iron-plate]", candidate.label },
          create_at_cursor = true,
        },
      }, flying_texts)
    end)

    it("shows nothing when the payload and key are both nil and there is no fallback", function()
      ActionDispatch.run(candidate, 1, function(_candidate, _player)
        return nil, nil
      end, function(_payload, _candidate, _player) end)

      assert.are.same({}, flying_texts)
    end)

    it("falls back to fallback_key when the payload and key are both nil", function()
      ActionDispatch.run(candidate, 1, function(_candidate, _player)
        return nil, nil
      end, function(_payload, _candidate, _player) end, "quidquid.action-open-remote-view-unavailable")

      assert.are.same({
        {
          text = { "quidquid.action-open-remote-view-unavailable", "[img=item/iron-plate]", candidate.label },
          create_at_cursor = true,
        },
      }, flying_texts)
    end)

    it("prefers the resolved key over fallback_key", function()
      ActionDispatch.run(candidate, 1, function(_candidate, _player)
        return nil, "quidquid.action-open-remote-view-not-visited"
      end, function(_payload, _candidate, _player) end, "quidquid.action-open-remote-view-unavailable")

      assert.are.same({
        {
          text = { "quidquid.action-open-remote-view-not-visited", "[img=item/iron-plate]", candidate.label },
          create_at_cursor = true,
        },
      }, flying_texts)
    end)
  end)
end)
