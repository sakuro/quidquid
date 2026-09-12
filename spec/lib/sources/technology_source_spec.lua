local TechnologySource = require("lib.sources.technology_source")

local function fake_translation_cache(entries)
  entries = entries or {}
  return {
    get = function(_, locale, internal_name)
      local by_locale = entries[locale]
      if by_locale == nil then
        return nil
      end
      return by_locale[internal_name]
    end,
  }
end

describe("TechnologySource", function()
  describe(".build_candidates", function()
    it("delegates to prototype_candidate with the technology type and icon prefix", function()
      local technologies = {
        { name = "steam-power", localised_name = {"technology-name.steam-power"}, hidden = false },
      }

      local candidates = TechnologySource.build_candidates("steam", technologies, "en", fake_translation_cache(), false)

      assert.are.equal(1, #candidates)
      assert.are.same(
        { type = "technology", id = "steam-power", label = {"technology-name.steam-power"}, icon = "technology/steam-power" },
        candidates[1]
      )
    end)
  end)
end)
