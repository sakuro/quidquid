local TechnologyUpgradeChain = {}

-- An `upgrade = true` family is a run of separate, finite prototypes
-- (braking-force-1 .. -7), not one multi-level prototype -- see
-- TechnologyPrerequisites.is_multi_level for that unrelated mechanism. The
-- technology screen's grid draws only part of such a run as tiles; its tree
-- view still shows every level, so this models what the grid offers, not what
-- the player can reach. Nothing in the runtime API reports which part the grid
-- draws, so the rule below was derived by observing it in game against states
-- set up over RCON. Every claim it makes is pinned by a case in
-- spec/lib/technology_upgrade_chain_spec.lua.

-- Splits "braking-force-6" into "braking-force" and 6. Returns nil for a name
-- that carries no trailing level, which every chain head may do
-- (speed-module heads speed-module-2, speed-module-3).
local function split_level(name)
  local base, level = name:match("^(.+)-(%d+)$")
  if base == nil then
    return nil
  end
  return base, tonumber(level)
end

-- The predecessor has to be both a prerequisite and a member of the same
-- chain by name. Neither test alone is enough: transport-belt-capacity-2
-- takes inserter-capacity-bonus-7 as a second upgrade prerequisite and in
-- game ignores it (researching only that one leaves -2 off the screen), while
-- speed-module-2's predecessor is speed-module, which no decrement produces.
-- The level below wins over the bare base when a chain somehow offers both,
-- so the answer never depends on pairs() order.
local function find_previous(name, prerequisites, upgrades)
  local base, level = split_level(name)
  if base == nil then
    return nil
  end
  local below = base .. "-" .. (level - 1)
  if upgrades[below] ~= nil and prerequisites[below] ~= nil then
    return below
  end
  if upgrades[base] ~= nil and prerequisites[base] ~= nil then
    return base
  end
  return nil
end

--- Links every `upgrade = true` technology to its neighbours in its chain.
---
--- Only the keys of a prototype's `prerequisites` are read, never the prototypes they
--- map to. Prototypes don't change while a save runs, so the result is worth caching
--- for the session -- but in a module upvalue, never in `storage`.
---@param technologies table  anything pairs() yields prototypes from: the array
---  TechnologySource collects in production, a plain list in a spec
---@return table  name -> { previous = name|nil, next = name|nil } for chain members only
function TechnologyUpgradeChain.build_links(technologies)
  local upgrades = {}
  for _, technology in pairs(technologies) do
    if technology.upgrade then
      upgrades[technology.name] = technology
    end
  end

  local links = {}
  for name, technology in pairs(upgrades) do
    links[name] = { previous = find_previous(name, technology.prerequisites, upgrades) }
  end

  -- Successors are the predecessor edges reversed, which can only be resolved
  -- once every predecessor is known. Two levels claiming one predecessor leave
  -- it without a successor instead of picking an arbitrary one: an unrecognized
  -- shape must err towards showing a technology, never towards hiding it.
  local ambiguous = {}
  for name, link in pairs(links) do
    local previous = link.previous
    if previous ~= nil then
      if ambiguous[previous] or links[previous].next ~= nil then
        links[previous].next = nil
        ambiguous[previous] = true
      else
        links[previous].next = name
      end
    end
  end

  return links
end

--- Whether the technology screen would show `name` as its own tile.
---
---   * a technology outside any upgrade chain is always shown
---   * a researched level is collapsed away once the level above it is researched, so
---     only the topmost researched level of a chain survives; a merely queued level
---     above does not collapse it
---   * an unresearched level appears once the level below it is researched or queued
---     -- one level past the frontier, no further. A chain head has no level below it
---     and is always shown.
---@param name string
---@param links table  as returned by build_links
---@param researched table  name set covering one force
---@param queued table  name set covering one force
---@return boolean
function TechnologyUpgradeChain.is_visible(name, links, researched, queued)
  local link = links[name]
  if link == nil then
    return true
  end
  if researched[name] then
    return link.next == nil or not researched[link.next]
  end
  local previous = link.previous
  return previous == nil or not not (researched[previous] or queued[previous])
end

return TechnologyUpgradeChain
