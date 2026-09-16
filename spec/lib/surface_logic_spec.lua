local SurfaceLogic = require("lib.surface_logic")

describe("SurfaceLogic", function()
  local function planet(overrides)
    local value = {
      kind = "planet",
      index = 1,
      name = "nauvis",
      label = { "space-location-name.nauvis" },
      icon = "space-location/nauvis",
      unlocked = true,
      hidden = false,
      search_name = "ナウヴィス",
    }
    for key, entry in pairs(overrides or {}) do
      value[key] = entry
    end
    return value
  end

  local function platform(overrides)
    local value = {
      kind = "platform",
      index = 2,
      name = "platform-1",
      label = "Cargo Express",
      search_name = "Cargo Express",
      icon = "surface/space-platform",
      own = true,
      friendly = false,
      hidden = false,
      force_name = "Blue Team",
    }
    for key, entry in pairs(overrides or {}) do
      value[key] = entry
    end
    return value
  end

  it("shows locked planets but prevents opening them in remote view", function()
    for _, include_hidden in ipairs({ false, true }) do
      assert.is_true(SurfaceLogic.is_visible(planet({ unlocked = false }), include_hidden))
      assert.are.equal(1, #SurfaceLogic.build_candidates("nauv", { planet({ unlocked = false }) }, include_hidden))
      assert.is_false(SurfaceLogic.can_open_remote_view(planet({ unlocked = false }), include_hidden))
      assert.is_true(SurfaceLogic.can_open_remote_view(planet(), include_hidden))
    end
  end)

  it("requires ownership or friendship independently of the hidden setting", function()
    for _, include_hidden in ipairs({ false, true }) do
      assert.is_false(SurfaceLogic.is_visible(platform({ own = false }), include_hidden))
      assert.is_true(SurfaceLogic.is_visible(platform(), include_hidden))
      assert.is_true(SurfaceLogic.is_visible(platform({ own = false, friendly = true }), include_hidden))
    end
  end)

  it("applies ownership and hidden rules to remote view too", function()
    assert.is_false(SurfaceLogic.can_open_remote_view(platform({ own = false }), true))
    assert.is_false(SurfaceLogic.can_open_remote_view(platform({ hidden = true }), false))
    assert.is_true(SurfaceLogic.can_open_remote_view(platform({ hidden = true }), true))
    assert.is_true(SurfaceLogic.can_open_remote_view(platform({ own = false, friendly = true }), false))
    assert.is_false(SurfaceLogic.can_open_remote_view(planet({ hidden = true }), false))
    assert.is_false(SurfaceLogic.can_open_remote_view(planet({ hidden = true, unlocked = false }), true))
  end)

  it("applies the hidden preference only to accessible surfaces", function()
    for _, value in ipairs({
      planet({ hidden = true }),
      platform({ hidden = true }),
      platform({ own = false, friendly = true, hidden = true }),
    }) do
      assert.is_false(SurfaceLogic.is_visible(value, false))
      assert.is_true(SurfaceLogic.is_visible(value, true))
    end
    assert.is_false(SurfaceLogic.is_visible({ kind = "other" }, true))
  end)

  it("matches internal names case insensitively and translated planet names", function()
    assert.are.equal(1, #SurfaceLogic.build_candidates("NAUV", { planet() }, false))
    assert.are.equal(1, #SurfaceLogic.build_candidates("ヴィス", { planet() }, false))
    assert.are.equal(0, #SurfaceLogic.build_candidates("vulcanus", { planet() }, false))
    assert.are.equal(1, #SurfaceLogic.build_candidates("nauv", { planet({ search_name = false }) }, false))
  end)

  it("includes an ungenerated planet but does not allow remote view", function()
    local ungenerated = planet({
      index = "vulcanus",
      name = "vulcanus",
      planet_name = "vulcanus",
      search_name = "Vulcanus",
      generated = false,
      unlocked = true,
    })

    local candidates = SurfaceLogic.build_candidates("vulcanus", { ungenerated }, false)

    assert.are.equal("vulcanus", candidates[1].id)
    assert.are.equal("vulcanus", candidates[1].planet_name)
    assert.is_false(SurfaceLogic.can_open_remote_view(ungenerated, false))
  end)

  it("matches platform display names and annotates only foreign ownership", function()
    local own = SurfaceLogic.build_candidates("express", { platform() }, false)[1]
    assert.are.equal("Cargo Express", own.label)
    local foreign = SurfaceLogic.build_candidates("express", { platform({ own = false, friendly = true }) }, false)[1]
    assert.are.same({ "quidquid.surface-with-force", "Cargo Express", "Blue Team" }, foreign.label)
  end)

  it("does not match a platform by its surface name", function()
    local candidates = SurfaceLogic.build_candidates("platform-1", { platform() }, false)
    assert.are.same({}, candidates)
  end)

  it("returns no candidates for an empty query", function()
    local candidates = SurfaceLogic.build_candidates("", { platform({ index = 9 }), planet(), platform() }, false)
    assert.are.same({}, candidates)
  end)

  it("keeps same-name platforms distinct and orders by surface index", function()
    local candidates = SurfaceLogic.build_candidates("a", {
      platform({ index = 9 }),
      planet({ name = "a", search_name = "a" }),
      platform(),
    }, false)
    assert.are.equal(3, #candidates)
    assert.are.same({ 1, 2, 9 }, { candidates[1].id, candidates[2].id, candidates[3].id })
    assert.are.equal("surface", candidates[1].type)
    assert.are.equal("space-location/nauvis", candidates[1].icon)
    assert.are.equal("surface/space-platform", candidates[2].icon)
  end)
end)
