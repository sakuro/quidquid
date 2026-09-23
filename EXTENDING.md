# Extending Quidquid

> **Draft.** Written from Quidquid's own implementation, not yet verified by
> building a mod against it. Expect gaps and mistakes; check the code, or open an
> issue, when something here does not match what you see.

Other mods can add their own search sources and palette actions. Everything goes
through Quidquid's `quidquid` remote interface — no change to Quidquid itself is
needed, and your code keeps running in your own mod.

The contract is versioned with `contract_version`, currently `1`. A registration
whose `contract_version` does not match is rejected outright, so a future bump
disables your registration until you update. Until Quidquid reaches 1.0, expect
the contract to change without a compatibility shim.

## Depending on Quidquid

Quidquid adds the `quidquid` interface while its `control.lua` is parsed, so mod
load order does not matter. What matters is whether Quidquid is installed at all.
List it in `info.json` as a dependency, or make it optional (`? quidquid`) and
guard every call:

```lua
if remote.interfaces["quidquid"] == nil then
  return
end
```

## When to register

`remote.call` is only valid inside an event. `on_init` fires only for a brand-new
save, `on_configuration_changed` only when something actually changed, and
`on_load` cannot use `remote` at all — none of them covers an ordinary continued
load. Register from the first `on_tick` after any load instead:

```lua
script.on_event(defines.events.on_tick, function()
  script.on_event(defines.events.on_tick, nil)
  remote.add_interface("my-mod-widget-source", { search = search })
  remote.call("quidquid", "register_source", { --[[ definition ]] })
end)
```

Register the handler at `control.lua`'s top level. Neither the handler nor the
registration survives a save/load, so both are re-established on the next load —
which is what makes dropping the handler safe.

A source with a translation dictionary of its own cannot drop the handler —
`flib_dictionary.on_tick()` has to run every tick to drive translation. Keep the
handler and gate the one-shot part with a plain local flag instead, the way
Quidquid's own `control.lua` does:

```lua
local flib_dictionary = require("__flib__.dictionary")

local registered = false

script.on_event(defines.events.on_tick, function()
  if not registered then
    registered = true
    remote.add_interface("my-mod-widget-source", { search = search })
    remote.call("quidquid", "register_source", { --[[ definition ]] })
  end
  flib_dictionary.on_tick()
end)

-- Registers flib's remaining events. It leaves on_tick alone, because the
-- handler above already holds it.
flib_dictionary.handle_events()
```

Keep the flag a plain local, **not** a field in `storage`. The registration does
not survive a save/load either, so a persisted flag would still be set on the
next load and the source would never register again.

## Sources

A source answers search queries with candidates of one type.

### Definition

| Field | Required | Meaning |
| --- | --- | --- |
| `contract_version` | yes | Must be `1`. |
| `type` | yes | The candidate type this source produces. Unique across all sources — a duplicate is rejected. Actions are matched to candidates by this string. |
| `id` | yes | Identifies your source in Quidquid's log messages. |
| `label` | yes | LocalisedString shown as the source label on each result row. |
| `prefixes` | no | Prefix words that lock the palette to this source — with `{ "w", "widget" }`, typing `widget ` locks to it. A prefix already taken by another source is ignored with a log line, as is an empty string. Defaults to none. |
| `in_default_search` | no | When true, the source takes part in the unlocked search. Defaults to `false`, which leaves it reachable only through a prefix. |
| `interface` | yes | Name of your remote interface implementing the functions below. |

A source with neither `prefixes` nor `in_default_search` cannot be reached at all.

### Interface functions

| Function | Required | Contract |
| --- | --- | --- |
| `search(query, player_index)` | yes | Returns an array of candidates. `query` is already whitespace-trimmed and may be empty. |
| `is_query_valid(query, player_index)` | no | Return `false` to mark the palette input as invalid for this query. Every searched source is asked; one `false` is enough. Omitted, every query is valid. |

Results from all searched sources are merged by `search_score` (higher first,
ties broken by source registration order) and the top 30 rows are shown.

### Candidates

| Field | Required | Meaning |
| --- | --- | --- |
| `type` | yes | Must be the source's own `type`; this is what actions resolve on. |
| `id` | yes | Your identifier for the entry. Handed back to actions verbatim. |
| `label` | yes | String or LocalisedString naming the entry. |
| `icon` | yes | SpritePath, rendered as `[img=...]`. |
| `search_score` | yes | Ranking score, higher first — see [Scoring](#scoring). A candidate without a numeric one raises an error that aborts the entire search, not just that candidate. |
| `search_display_name` | no | Plain string shown instead of `label` as the name — only a plain string can carry match highlighting. Omitted, `label` is shown. |
| `search_internal_name` | no | Plain string shown as the muted second line (Quidquid's own sources put the prototype name here). Omitted, `secondary_text` takes that line. |
| `search_display_ranges`, `search_internal_ranges` | no | Arrays of tables with `start_byte` and `end_byte`, marking the matched part of the corresponding name in bold. Omitted, that name is shown without highlighting. |
| `secondary_text` | no | Muted second line for a candidate with no `search_internal_name`. Omitted, such a candidate has no second line. |
| `numeric` | no | Right-align the name column, for a candidate whose label is a value rather than a name. Defaults to `false`. |
| `annotation` | no | A table with `caption` and `tooltip` LocalisedStrings. The caption is shown at the right end of the row, the tooltip above the action hints. Omitted, the right end carries only the source label. |

### Scoring

Candidates from every searched source are sorted together, so `search_score` only
works as a ranking if all sources agree on a scale. Quidquid's own sources score
with `lib/fuzzy_match.lua` (adapted from fzy): an exact match scores `math.huge`,
a partial match roughly the number of consecutively matched characters, with
smaller bonuses at word boundaries and a penalty per gap — which can push a thin
match slightly below zero. A match on the translated name is rewarded with an
extra 0.5 over the same match on the internal name.

Rather than reproduce that, take it from Quidquid:

```lua
local quidquid = require("__quidquid__.lib.api")

local function search(query, player_index)
  local player = game.get_player(player_index)
  -- Normalizes the query once. Build it per search, not per candidate.
  local matcher = quidquid.matcher(query, player.locale)
  local candidates = {}

  for _, entry in ipairs(my_entries()) do
    local match = matcher:match("my-mod", entry.id, {
      display = entry.translated_name,
      internal = entry.name,
    })
    if match ~= nil then
      table.insert(candidates, {
        type = "my-mod-widget",
        id = entry.id,
        label = entry.label,
        icon = entry.icon,
        search_display_name = entry.translated_name,
        search_internal_name = entry.name,
        search_display_ranges = match.display_ranges,
        search_internal_ranges = match.internal_ranges,
        search_score = match.score,
      })
    end
  end
  return candidates
end
```

`matcher:match(namespace, id, fields)` returns `nil` when neither field matches,
otherwise the score and the byte ranges that matched, already in the shape the
candidate fields expect. Either field may be omitted. The `namespace` and `id`
key a cache of normalized names, so pick a namespace of your own and an `id` that
is stable for the entry.

A renamed entry needs nothing from you: the cache keeps the raw value it
normalized and compares it on every read. An entry that *disappears* never gets
that read, so its keys sit in the cache for the rest of the session —
`quidquid.forget(namespace, id)` drops them. It takes a whole namespace when given
no `id`, and everything when given neither. This is a memory question, not a
correctness one; a source over prototypes has nothing to forget.

Requiring this module needs Quidquid as a hard dependency, not an optional one.
It is the only file under `__quidquid__` meant to be required from outside;
everything else there is internal and moves without notice. The module itself is
experimental until Quidquid reaches 1.0, and it is not covered by
`contract_version` — that number versions the remote contract above, not this.

### Minimal example

```lua
local function search(query, player_index)
  if query == "" then
    return {}
  end
  return {
    {
      type = "my-mod-widget",
      id = "widget-1",
      label = { "my-mod.widget-1" },
      icon = "item/iron-plate",
      search_score = 1,
    },
  }
end

remote.add_interface("my-mod-widget-source", { search = search })
remote.call("quidquid", "register_source", {
  contract_version = 1,
  id = "my-mod-widgets",
  type = "my-mod-widget",
  label = { "my-mod.source-widgets" },
  prefixes = { "w", "widget" },
  in_default_search = true,
  interface = "my-mod-widget-source",
})
```

## Actions

An action is a key binding that runs against the selected candidate, for every
candidate type it declares. It may act on types owned by other mods, including
Quidquid's own (`item`, `fluid`, `recipe`, `technology`, `surface`).

### Definition

| Field | Required | Meaning |
| --- | --- | --- |
| `contract_version` | yes | Must be `1`. |
| `id` | yes | Identifies the action in log messages and names its tooltip locale key (see below). Prefix it with your mod name so it cannot collide with Quidquid's own ids. |
| `types` | yes | Non-empty array of candidate types this action applies to. |
| `label` | yes | LocalisedString naming the action in the candidate tooltip. |
| `input_name` | yes | Name of a custom-input prototype you define in the data stage. Quidquid registers the event handler for it. One action per type and `input_name`; a later registration for the same pair is ignored with a log line. |
| `interface` | yes | Name of your remote interface implementing the functions below. |

### Interface functions

| Function | Required | Contract |
| --- | --- | --- |
| `execute(candidate, player_index)` | yes | Performs the action on the selected candidate. |
| `is_available(player_index)` | no | Return `false` to hide the action. Omitted, the action is always offered for its types. |

`is_available` may only gate on state that is uniform across every candidate of a
type, such as the player's own state. Whether one particular candidate can be
acted on is a fact for `execute` to resolve and report to the player — hiding it
in `is_available` removes the action from the tooltip without saying why.

### Tooltip hint locale key

The tooltip line for an action reads `<label> (<key binding>)`. The engine only
substitutes `__CONTROL__<input>__` for text that comes from a locale file, so the
key binding part is read from `quidquid.action-<id>-hint` — in the **`quidquid`**
locale category, not yours. Locale categories merge across mods, so add it to
your own locale file:

```ini
[quidquid]
my-mod-do-thing-hint=__CONTROL__my-mod-do-thing__
```

Without that entry the tooltip shows an unknown-key marker.

### Minimal example

```lua
local function execute(candidate, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return
  end
  player.print(candidate.id)
end

remote.add_interface("my-mod-do-thing-action", { execute = execute })
remote.call("quidquid", "register_action", {
  contract_version = 1,
  id = "my-mod-do-thing",
  types = { "my-mod-widget", "item" },
  label = { "my-mod.action-do-thing" },
  input_name = "my-mod-do-thing",
  interface = "my-mod-do-thing-action",
})
```

## Rejections and failures

Both `register_source` and `register_action` return a boolean and never raise. A
registration is rejected — and the reason written to the Factorio log — on a
`contract_version` mismatch, a missing `type`, a `type` already owned by another
source, or a missing `input_name`/`types`. A prefix or a type/`input_name` pair
that is already taken is skipped with a log line while the rest of the
registration succeeds.

Quidquid calls `search`, `is_query_valid`, `execute` and `is_available` through
`pcall`. An error inside them is logged and treated as no results, a valid query,
nothing done, or unavailable respectively — so a broken source or action looks
silently inert in game. Check the log.

## Translated names

Quidquid's translated prototype names are not shared — flib's dictionary state
lives in each mod's own `storage`. A source that matches on translated names
keeps its own dictionary. With flib, create it from `on_init` and
`on_configuration_changed`: that has to happen before the first `on_tick`, so it
cannot ride along with the registration above.

## Reference implementations

These are Quidquid's own sources and actions, shown as examples. Apart from
`lib/api.lua`, nothing under `lib/` is a public API — read them, don't require
them.

| File | Shows |
| --- | --- |
| [`lib/sources/calculator_source.lua`](lib/sources/calculator_source.lua) | The smallest source, plus `is_query_valid` and `secondary_text` |
| [`lib/sources/fluid_source.lua`](lib/sources/fluid_source.lua) | A prototype-backed source with a translation dictionary |
| [`lib/sources/item_source.lua`](lib/sources/item_source.lua) | Per-candidate `annotation` |
| [`lib/actions/open_factoriopedia_action.lua`](lib/actions/open_factoriopedia_action.lua) | The smallest action, acting on several types |
| [`lib/actions/temporary_request_action.lua`](lib/actions/temporary_request_action.lua) | `is_available` against player state |
