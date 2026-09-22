local build_candidates = require("lib.sources.prototype_candidate")

describe("prototype_candidate", function()
  local candidate_type = "item"
  local icon_prefix = "item"

  it("returns nothing for an empty prototype list", function()
    local candidates = build_candidates(candidate_type, icon_prefix, "iron", {}, "en", {}, false)

    assert.are.same({}, candidates)
  end)

  it("returns nothing for an empty query", function()
    local prototype_list = {
      { name = "iron-plate", localised_name = { "item-name.iron-plate" }, hidden = false },
    }

    local candidates = build_candidates(candidate_type, icon_prefix, "", prototype_list, "en", {}, false)

    assert.are.same({}, candidates)
  end)

  it("matches a prototype by internal name", function()
    local prototype_list = {
      { name = "iron-plate", localised_name = { "item-name.iron-plate" }, hidden = false },
    }

    local candidates = build_candidates(candidate_type, icon_prefix, "iron", prototype_list, "en", {}, false)

    assert.are.equal(1, #candidates)
    assert.are.equal("item", candidates[1].type)
    assert.are.equal("iron-plate", candidates[1].id)
    assert.are.same({ "item-name.iron-plate" }, candidates[1].label)
    assert.are.equal("item/iron-plate", candidates[1].icon)
    assert.is_nil(candidates[1].search_display_name)
    assert.are.equal("iron-plate", candidates[1].search_internal_name)
    assert.is_number(candidates[1].search_score)
  end)

  it("does not mark a candidate as numeric -- only the calculator source's own results are", function()
    local prototype_list = {
      { name = "iron-plate", localised_name = { "item-name.iron-plate" }, hidden = false },
    }

    local candidates = build_candidates(candidate_type, icon_prefix, "iron", prototype_list, "en", {}, false)

    assert.is_nil(candidates[1].numeric)
  end)

  it("matches non-consecutive characters and returns their positions", function()
    local prototype_list = {
      { name = "iron-plate", localised_name = { "item-name.iron-plate" }, hidden = false },
    }

    local candidates = build_candidates(candidate_type, icon_prefix, "ipl", prototype_list, "en", {}, false)

    assert.are.equal(1, #candidates)
    assert.are.same({ 1, 6, 7 }, candidates[1].search_positions)
    assert.are.same({}, candidates[1].search_display_ranges)
    assert.are.same({
      { start_byte = 1, end_byte = 1 },
      { start_byte = 6, end_byte = 6 },
      { start_byte = 7, end_byte = 7 },
    }, candidates[1].search_internal_ranges)
  end)

  it("matches a prototype only by its cached translated name", function()
    -- The query "鉄" is not a substring of the internal name "iron-plate" itself, so this
    -- can only pass via the translated-name fallback, not the internal-name path.
    local prototype_list = {
      { name = "iron-plate", localised_name = { "item-name.iron-plate" }, hidden = false },
    }
    local translated_names = { ["iron-plate"] = "鉄板" }

    local candidates =
      build_candidates(candidate_type, icon_prefix, "鉄", prototype_list, "en", translated_names, false)

    assert.are.equal(1, #candidates)
    assert.are.equal("iron-plate", candidates[1].id)
  end)

  it("matches a translated name case- and accent-insensitively", function()
    local prototype_list = {
      { name = "cafe", localised_name = { "item-name.cafe" }, hidden = false },
    }
    local translated_names = { cafe = "Café" }

    local candidates =
      build_candidates(candidate_type, icon_prefix, "CAFE", prototype_list, "en", translated_names, false)

    assert.are.equal(1, #candidates)
  end)

  it("prefers a localized fuzzy match when both fields match", function()
    local prototype_list = {
      { name = "iron-plate", localised_name = { "item-name.iron-plate" }, hidden = false },
    }
    local translated_names = { ["iron-plate"] = "Iron Plate" }

    local candidates =
      build_candidates(candidate_type, icon_prefix, "ipl", prototype_list, "en", translated_names, false)

    assert.are.equal(1, #candidates)
    assert.are.equal("display", candidates[1].search_field)
    assert.are.equal("Iron Plate", candidates[1].search_display_name)
    assert.are.equal("iron-plate", candidates[1].search_internal_name)
    assert.are.same({
      { start_byte = 1, end_byte = 1 },
      { start_byte = 6, end_byte = 6 },
      { start_byte = 7, end_byte = 7 },
    }, candidates[1].search_display_ranges)
    assert.are.same({}, candidates[1].search_internal_ranges)
  end)

  it("matches Japanese hiragana against a katakana translation", function()
    local prototype_list = {
      { name = "belt", localised_name = { "item-name.belt" }, hidden = false },
    }
    local translated_names = { belt = "ベルト" }

    local candidates =
      build_candidates(candidate_type, icon_prefix, "べると", prototype_list, "ja", translated_names, false)

    assert.are.equal(1, #candidates)
  end)

  it("excludes a prototype that matches neither name", function()
    local prototype_list = {
      { name = "iron-plate", localised_name = { "item-name.iron-plate" }, hidden = false },
    }

    local candidates = build_candidates(candidate_type, icon_prefix, "copper", prototype_list, "en", {}, false)

    assert.are.same({}, candidates)
  end)

  it("does not match when the translated-name entry is absent", function()
    -- Same non-matching-on-internal-name query as the previous test, but this time the
    -- prototype has no entry at all in translated_names (flib omits failed/not-yet-done
    -- translations rather than storing a sentinel) — this must NOT be treated as a match.
    local prototype_list = {
      { name = "iron-plate", localised_name = { "item-name.iron-plate" }, hidden = false },
    }

    local candidates = build_candidates(candidate_type, icon_prefix, "鉄", prototype_list, "en", {}, false)

    assert.are.same({}, candidates)
  end)

  it("excludes a hidden prototype when include_hidden is false", function()
    local prototype_list = {
      { name = "debug-marker", localised_name = { "item-name.debug-marker" }, hidden = true },
    }

    local candidates = build_candidates(candidate_type, icon_prefix, "debug", prototype_list, "en", {}, false)

    assert.are.same({}, candidates)
  end)

  it("includes a hidden prototype when include_hidden is true", function()
    local prototype_list = {
      { name = "debug-marker", localised_name = { "item-name.debug-marker" }, hidden = true },
    }

    local candidates = build_candidates(candidate_type, icon_prefix, "debug", prototype_list, "en", {}, true)

    assert.are.equal(1, #candidates)
  end)

  it("filters a mixed list down to only the matching, visible prototypes", function()
    local prototype_list = {
      { name = "iron-plate", localised_name = { "item-name.iron-plate" }, hidden = false },
      { name = "copper-plate", localised_name = { "item-name.copper-plate" }, hidden = false },
      { name = "iron-ore", localised_name = { "item-name.iron-ore" }, hidden = false },
      { name = "secret-plate", localised_name = { "item-name.secret-plate" }, hidden = true },
    }

    local candidates = build_candidates(candidate_type, icon_prefix, "plate", prototype_list, "en", {}, false)

    assert.are.equal(2, #candidates)
    assert.are.equal("iron-plate", candidates[1].id)
    assert.are.equal("copper-plate", candidates[2].id)
  end)

  it("uses the given candidate_type and icon_prefix for a different category", function()
    local prototype_list = {
      { name = "steam-power", localised_name = { "technology-name.steam-power" }, hidden = false },
    }

    local candidates = build_candidates("technology", "technology", "steam", prototype_list, "en", {}, false)

    assert.are.equal(1, #candidates)
    assert.are.equal("technology", candidates[1].type)
    assert.are.equal("steam-power", candidates[1].id)
    assert.are.same({ "technology-name.steam-power" }, candidates[1].label)
    assert.are.equal("technology/steam-power", candidates[1].icon)
    assert.is_number(candidates[1].search_score)
  end)

  it("keeps candidate_type and icon_prefix independent even when they differ", function()
    -- Every other case uses the same string for both, which would let a transposed
    -- `type`/`icon` assignment in the implementation slip past unnoticed.
    local prototype_list = {
      { name = "steam-power", localised_name = { "technology-name.steam-power" }, hidden = false },
    }

    local candidates = build_candidates("technology", "tech-icon", "steam", prototype_list, "en", {}, false)

    assert.are.equal(1, #candidates)
    assert.are.equal("technology", candidates[1].type)
    assert.are.equal("tech-icon/steam-power", candidates[1].icon)
  end)
end)
