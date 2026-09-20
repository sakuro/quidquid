-- Factorio's own load mechanism fixes which globals are available at which
-- stage; see docs/superpowers/specs/2026-09-20-luacheck-design.md for the
-- citations. lib/** deliberately gets the union of every stage's globals
-- rather than being pinned to control-only ones: AGENTS.md documents it as
-- holding helpers "shared across stages", not just control-stage logic.
std = "lua52"

read_globals = {
  "mods",
  "log",
}

local data_stage_globals = { "data" }
local control_stage_globals = {
  "game",
  "script",
  "remote",
  "defines",
  "helpers",
  "prototypes",
  "commands",
  "rcon",
  "rendering",
}

-- `storage` is the one control-stage global mods are meant to write into (it
-- is the mod's own persisted-state table, initialized empty by Factorio) —
-- unlike the rest of control_stage_globals, which are only ever read/called.
-- Kept as `globals`, not `read_globals`, wherever control_stage_globals
-- applies, so field writes like `storage.foo = storage.foo or {}` don't trip
-- "setting read-only field of global storage".
local control_stage_write_globals = { "storage" }

local function concat(...)
  local result = {}
  for _, list in ipairs({ ... }) do
    for _, name in ipairs(list) do
      table.insert(result, name)
    end
  end
  return result
end

files["settings.lua"] = { read_globals = data_stage_globals }
files["data.lua"] = { read_globals = data_stage_globals }
files["prototypes/**/*.lua"] = { read_globals = data_stage_globals }
files["control.lua"] = { read_globals = control_stage_globals, globals = control_stage_write_globals }
files["lib/**/*.lua"] = {
  read_globals = concat(data_stage_globals, control_stage_globals),
  globals = control_stage_write_globals,
}

-- spec/**/*_spec.lua needs no override here: luacheck's own default
-- (files["**/spec/**/*_spec.lua"].std = "+busted") already matches this
-- project's spec file naming and supplies the busted DSL globals.

-- spec/helper.lua assigns `storage = storage or {}` at module scope (a
-- Factorio-global *write*, not just a read) to stub it for specs that need
-- it defined before the code under test loads.
files["spec/helper.lua"] = { globals = { "storage" } }

-- RemoteCaller is a stateless namespace module: its methods use `:` syntax
-- only to match RemoteCaller:has/:call call sites, not because they read or
-- write instance state via `self`.
files["lib/remote_caller.lua"] = { self = false }
