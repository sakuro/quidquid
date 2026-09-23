local TechnologyUpgradeChain = require("lib.technology_upgrade_chain")

-- Shaped like the part of LuaTechnologyPrototype this module reads. Only the
-- keys of `prerequisites` matter -- a real prototype maps them to prototypes,
-- which the module never dereferences.
local function technology(name, options)
  options = options or {}
  local prerequisites = {}
  for _, prerequisite_name in ipairs(options.prerequisites or {}) do
    prerequisites[prerequisite_name] = true
  end
  return { name = name, upgrade = options.upgrade or false, prerequisites = prerequisites }
end

-- braking-force-1 .. -N, the chain the in-game observations were made against.
local function braking_force(levels)
  local list = { technology("braking-force-1", { upgrade = true }) }
  for level = 2, levels do
    list[#list + 1] = technology("braking-force-" .. level, {
      upgrade = true,
      prerequisites = { "braking-force-" .. (level - 1) },
    })
  end
  return list
end

local function name_set(names)
  local set = {}
  for _, name in ipairs(names or {}) do
    set[name] = true
  end
  return set
end

describe("TechnologyUpgradeChain", function()
  describe(".build_links", function()
    it("leaves a technology that is not an upgrade out of the links", function()
      local links = TechnologyUpgradeChain.build_links({ technology("automation") })

      assert.is_nil(links["automation"])
    end)

    it("gives a chain head no predecessor", function()
      local links = TechnologyUpgradeChain.build_links(braking_force(3))

      assert.is_nil(links["braking-force-1"].previous)
    end)

    it("links a level to the level below it", function()
      local links = TechnologyUpgradeChain.build_links(braking_force(3))

      assert.are.equal("braking-force-1", links["braking-force-2"].previous)
      assert.are.equal("braking-force-3", links["braking-force-2"].next)
    end)

    -- speed-module / speed-module-2 / speed-module-3: the chain head carries no
    -- level suffix, so a predecessor cannot be found by decrementing alone.
    it("links a level to a predecessor whose name has no level suffix", function()
      local links = TechnologyUpgradeChain.build_links({
        technology("speed-module", { upgrade = true }),
        technology("speed-module-2", { upgrade = true, prerequisites = { "speed-module" } }),
      })

      assert.are.equal("speed-module", links["speed-module-2"].previous)
    end)

    -- transport-belt-capacity-2 has two upgrade prerequisites, one of them from
    -- an unrelated chain. In game it becomes visible once transport-belt-capacity-1
    -- alone is researched, and stays hidden when only inserter-capacity-bonus-7 is.
    it("picks the prerequisite from its own chain when several chains are prerequisites", function()
      local links = TechnologyUpgradeChain.build_links({
        technology("inserter-capacity-bonus-7", { upgrade = true }),
        technology("transport-belt-capacity-1", { upgrade = true }),
        technology("transport-belt-capacity-2", {
          upgrade = true,
          prerequisites = { "transport-belt-capacity-1", "inserter-capacity-bonus-7" },
        }),
      })

      assert.are.equal("transport-belt-capacity-1", links["transport-belt-capacity-2"].previous)
      assert.is_nil(links["inserter-capacity-bonus-7"].next)
    end)

    -- Erring towards visible: an unrecognized shape must not hide anything.
    it("gives no predecessor when no prerequisite belongs to its own chain", function()
      local links = TechnologyUpgradeChain.build_links({
        technology("inserter-capacity-bonus-7", { upgrade = true }),
        technology("belt-speed-2", { upgrade = true, prerequisites = { "inserter-capacity-bonus-7" } }),
      })

      assert.is_nil(links["belt-speed-2"].previous)
    end)

    it("records no successor when two levels claim the same predecessor", function()
      local links = TechnologyUpgradeChain.build_links({
        technology("overhaul", { upgrade = true }),
        technology("overhaul-2", { upgrade = true, prerequisites = { "overhaul" } }),
        technology("overhaul-1", { upgrade = true, prerequisites = { "overhaul" } }),
      })

      assert.is_nil(links["overhaul"].next)
    end)
  end)

  describe(".is_visible", function()
    local links

    before_each(function()
      links = TechnologyUpgradeChain.build_links(braking_force(7))
    end)

    it("shows a technology that is not an upgrade", function()
      local plain = TechnologyUpgradeChain.build_links({ technology("automation") })

      assert.is_true(TechnologyUpgradeChain.is_visible("automation", plain, {}, {}))
    end)

    it("shows a chain head", function()
      assert.is_true(TechnologyUpgradeChain.is_visible("braking-force-1", links, {}, {}))
    end)

    it("shows a level whose predecessor is researched", function()
      local researched = name_set({ "braking-force-1" })

      assert.is_true(TechnologyUpgradeChain.is_visible("braking-force-2", links, researched, {}))
    end)

    it("shows a level whose predecessor is queued", function()
      local queued = name_set({ "braking-force-1" })

      assert.is_true(TechnologyUpgradeChain.is_visible("braking-force-2", links, {}, queued))
    end)

    it("hides a level whose predecessor is neither researched nor queued", function()
      assert.is_false(TechnologyUpgradeChain.is_visible("braking-force-2", links, {}, {}))
    end)

    it("hides a researched level whose next level is researched", function()
      local researched = name_set({ "braking-force-1", "braking-force-2" })

      assert.is_false(TechnologyUpgradeChain.is_visible("braking-force-1", links, researched, {}))
    end)

    -- Only a researched next level collapses the one below it: in game,
    -- braking-force-2 stays on screen while braking-force-3 sits in the queue.
    it("shows a researched level whose next level is only queued", function()
      local researched = name_set({ "braking-force-1", "braking-force-2" })
      local queued = name_set({ "braking-force-3" })

      assert.is_true(TechnologyUpgradeChain.is_visible("braking-force-2", links, researched, queued))
    end)

    -- The whole observed screen: braking-force-1 and -2 researched, -3 .. -5
    -- queued. The technology screen showed -2 through -6 and nothing else.
    it("reproduces the technology screen of the observed save", function()
      local researched = name_set({ "braking-force-1", "braking-force-2" })
      local queued = name_set({ "braking-force-3", "braking-force-4", "braking-force-5" })
      local visible = {}
      for level = 1, 7 do
        local name = "braking-force-" .. level
        if TechnologyUpgradeChain.is_visible(name, links, researched, queued) then
          visible[#visible + 1] = name
        end
      end

      assert.are.same({
        "braking-force-2",
        "braking-force-3",
        "braking-force-4",
        "braking-force-5",
        "braking-force-6",
      }, visible)
    end)
  end)
end)
