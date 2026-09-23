-- Runs once before any spec is loaded (busted `helper` option; see .busted).
-- Use it for setup that must be in place before the code under test is first
-- required -- e.g. shared stubs for Factorio globals. Keep every statement
-- idempotent so an in-process re-run stays safe. No-op by default.

storage = storage or {}

-- flib ships as a Factorio mod zip, not a luarocks package, so
-- require("__flib__.dictionary") cannot resolve under plain Lua/busted.
-- Sources that migrated to it (see docs/superpowers/plans/2026-09-17-flib-dictionary-migration.md)
-- require it at module scope, so a stub must be in place before their specs
-- require those modules. Specs only exercise each source's build_candidates
-- wrapper, never these functions directly.
package.loaded["__flib__.dictionary"] = package.loaded["__flib__.dictionary"]
  or {
    new = function() end,
    add = function() end,
    get = function() end,
  }

-- lib/api.lua is meant to be required from other mods, so it names its own siblings
-- the way Factorio needs for that -- require("__quidquid__.lib.x"), see the comment
-- at the top of that file. Plain Lua has no such prefix, so resolve it back onto the
-- repo-relative path. Guarded through package.loaded rather than a flag global, both
-- to stay idempotent and to keep luacheck's allowed globals for this file as they are.
if package.loaded["__quidquid__.spec.path"] == nil then
  package.loaded["__quidquid__.spec.path"] = true
  table.insert(package.searchers, function(name)
    local relative = name:match("^__quidquid__%.(.+)$")
    if relative == nil then
      return nil
    end
    return function()
      return require(relative)
    end
  end)
end
