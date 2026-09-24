# Contributing

## Development setup

This project manages its toolchain with [mise](https://mise.jdx.dev/). After cloning:

1. `mise trust` — `mise.toml` defines `[env]` and `[hooks]`, which mise applies only for trusted configs.
2. `mise install` — installs the pinned tools. Its `postinstall` hook then runs `hk install` to register this repository's Git hooks, and installs `busted` for the test suite and `luacheck` for static analysis.

Review `hk.pkl` and the `git-hooks` package it imports before running the above: `hk install` configures hooks that execute on every commit and push. They enforce, among other things, that commit subjects start with a GitHub `:emoji:` code.

Then `mise run format` formats Lua code, `mise run lint` runs `luacheck`, `mise run test` runs the unit tests, and `mise tasks ls -l` lists this project's tasks (`-l` drops tasks inherited from mise's global config).

### Notes

- Re-run `mise install` after pulling changes to `mise.toml`; Renovate bumps tool versions regularly.
- Building Lua from source needs the readline development headers (`libreadline-dev` on Debian/Ubuntu, `readline` via Homebrew on macOS).

## Pull requests

When opening a pull request:

- Do not change the version in `info.json`. Version bumping is handled by the release workflow.
- Document any user-visible change in `changelog.txt` (see below).

## Comment conventions

Public functions in `lib/` — `function Module.name(...)` and
`function Module:name(...)` — carry a doc comment in three layers:

```lua
--- Rounds value up to the next multiple of size.
---
--- Pressing "+1 Stack" always adds at least one full stack, so the result is
--- strictly greater than value even when value is already an exact multiple.
---@param value number
---@param size number
---@return number
function Module.round_up(value, size)
```

- The **summary** is one line, required, and starts with a verb in the present
  tense (`Decides ...`, `True when ...`). It is not a restatement of the
  function's name.
- The **rationale paragraph** is optional and says *why*, not *what*: behavior
  confirmed over RCON, a Factorio quirk being worked around, why the caller
  passes a value already extracted from the runtime. What the function does is
  the summary's and the tags' job, so it is not repeated here. This is why one
  function has a three-line comment and another fifteen: the difference is how
  much rationale there is to record, not how carefully it was documented.
- **`---@param`** appears once per declared parameter, in declaration order.
  Obvious ones carry only a type; ones with a contract carry a note
  (`---@param filters LuaLogisticPoint.filters  plain array, already extracted by the caller`).
  `self` is implicit in a `:` declaration and is not documented. Varargs are
  `---@param ... <type>`.
- **`---@return`** appears once per returned value, in order, and includes
  `|nil` when nil is a possible result (`---@return LuaTechnology|nil`). A
  function that returns nothing gets no tag.
- Type names use the Factorio API's own spelling (`LuaPlayer`, `LuaLogisticPoint`,
  `uint`) or plain Lua types (`string`, `number`, `boolean`, `table`). Nothing
  reads these as types — no language server runs here — so they are documentation
  for human readers, and a `table` whose shape matters is better described by the
  API name it mirrors plus a note.
- Comments **inside** a function body stay there. A comment explaining why one
  line is the way it is belongs next to that line; only the description of the
  function itself belongs above it.
- Local functions are the author's judgement call: document the ones that are not
  obvious from their name and a few lines of body. A local exported by assignment
  (`Module.name = name`) is documented at its definition.

`mise run doc-check` enforces the mechanical half of this: a `---` block with a
summary line, one `---@param` per declared parameter in the right order, and a
`---@return` on any function that returns a value. It does not check types or
prose.

Public functions written before this convention are listed in
`.doc-check-baseline`, which suppresses them. The list can only shrink:
`doc-check` also fails on an entry whose function is now documented, or gone.
Regenerate it with `mise run doc-check -- --write-baseline > .doc-check-baseline`
— but as a rule, delete the lines you fixed rather than regenerating, so an
accidental regression cannot be absorbed into the baseline.

`tools/doc_check_test.sh` is the checker's own fixture test; CI runs it. A doc
checker that silently passes everything would make the baseline a lie, so changes
to `tools/doc_check.lua` belong with a case in that test.

## Changelog

`changelog.txt` uses Factorio's changelog format. On top of that, this project
marks the section for not-yet-released changes as `Version: Unreleased`. The
release workflow renames that section to the released version and does not open
a new one, so between releases the file starts with the last released version.

The first user-visible change of a new cycle therefore needs a fresh
`Unreleased` section at the top of the file:

```
---------------------------------------------------------------------------------------------------
Version: Unreleased
  Changes:
    - Describe the change here.
```

Add later entries to that same section. Do not create a section for the next
version number — the release workflow does the version bump.

## Scaffold drift

This repository is generated from
[`factorio-mod-scaffold`](https://github.com/sakuro/factorio-mod-scaffold). (In
`factorio-mod-scaffold` itself this workflow is a deliberate no-op — there is no
`.scaffold-sync.json`.) A weekly workflow
(`.github/workflows/scaffold-drift.yml`) three-way merges the
shared-infrastructure files listed in `.scaffold-sync.paths` against the current
scaffold and opens or updates one PR on branch `chore/scaffold-drift` when the
scaffold has moved ahead. `.scaffold-sync.json` records the scaffold commit this
repo was last synced to.

**Reviewing a `chore/scaffold-drift` PR**

- The PR is opened with `GITHUB_TOKEN`, so CI does not start on its own. Add the
  `run-ci` label to start it; CI removes that label as it runs, so after a later
  push from the workflow you re-run CI by adding `run-ci` again. (CI runs
  for real on every `labeled` event — there is no label-name filter, since a
  skipped required check counts as passing — so adding any label also re-runs
  it.)
- Require the test lane (if this repo has one) to pass.
- Check that MOD-specific content survived: `mise.toml` `[env] MOD_*`, any doc
  sections this repo added, real `spec/*_spec.lua`.
- The PR body links the scaffold compare range and notes each conflict the skill
  resolved.
- **Held-back paths.** An automated (CI) drift PR cannot carry changes under
  `.github/workflows/**` (`GITHUB_TOKEN` has no `workflows` permission) or under
  `.claude/**` (the CI agent's sandbox blocks writes there). The PR body's
  "Held back" section has a diff for each; the baseline is *not* bumped and the
  job keeps reporting drift until they are applied. A workflow diff that is only
  `uses:` SHA/tag pin bumps can be left for Renovate; everything else — and every
  `.claude/**` change — is applied by hand (a direct commit or a small PR). Then
  set `.scaffold-sync.json` `commit` to the head SHA in the compare link and
  `synced_at` to the current UTC time. (Running `/resolve-scaffold-drift` locally
  in Claude Code has neither limit and applies everything.)
- `changelog.txt` is intentionally untouched — tracked paths are `export-ignore`d
  development infrastructure.

**When it runs**

Only with an `ANTHROPIC_API_KEY` repo secret set; blank means the workflow's gate
step no-ops. A fork does not inherit the secret, so the workflow does nothing on
a fork and no API cost is incurred.

The first scheduled run can fail the action's `checkHumanActor` check because
`github.actor` on a `schedule` event is not a `User`. If that happens, set the
`claude-code-action` `allowed_bots` input in `scaffold-drift.yml`.

**Test lane**

A repo with no `.busted` file has dropped the test lane. The sync never re-adds
the test files (`ci.yml`, `.busted`, `tasks/test`, `spec/helper.lua`) or the
Lua-testing fragments in `mise.toml` / `.github/renovate.json`.

**If a sync looks wrong**

Close the PR. The next weekly run force-pushes `chore/scaffold-drift` again and
opens a fresh PR from the same baseline (the merge is recomputed each run). To
move the baseline, edit `.scaffold-sync.json`. The canonical description of this
mechanism is this section plus `.github/workflows/scaffold-drift.yml`,
`.scaffold-sync.paths`, and `.claude/skills/resolve-scaffold-drift/`.
