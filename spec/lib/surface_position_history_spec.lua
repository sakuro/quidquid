local History = require("lib.surface_position_history")

describe("Surface position history", function()
  it("remembers independent positions per player and surface without aliasing", function()
    local history = {}
    local position = { x = 10, y = 20 }
    History.remember(history, 1, 2, position)
    position.x = 99
    History.remember(history, 2, 2, { x = 30, y = 40 })
    History.remember(history, 1, 3, { x = 50, y = 60 })
    assert.are.same({ x = 10, y = 20 }, History.get(history, 1, 2))
    assert.are.same({ x = 30, y = 40 }, History.get(history, 2, 2))
    assert.are.same({ x = 50, y = 60 }, History.get(history, 1, 3))
  end)

  it("uses a fallback for unseen surfaces and removes deleted surfaces for all players", function()
    local history = {}
    local fallback = { x = 0, y = 0 }
    assert.are.same(fallback, History.get(history, 1, 2, fallback))
    History.remember(history, 1, 2, { x = 10, y = 20 })
    History.remember(history, 2, 2, { x = 30, y = 40 })
    History.remove_surface(history, 2)
    assert.are.same(fallback, History.get(history, 1, 2, fallback))
    assert.are.same(fallback, History.get(history, 2, 2, fallback))
  end)
end)
