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
which is what makes dropping the handler safe. For the same reason, never keep an
"already registered" flag in `storage`: it would still be set after the next
load, and your source would never register again.

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

The flag is a plain local for the same reason as above: it has to reset on every
load.

## Sources

A source answers search queries with candidates of one type.

### Definition

| Field | Required | Meaning |
| --- | --- | --- |
| `contract_version` | yes | Must be `1`. |
| `type` | yes | The candidate type this source produces. Unique across all sources — a duplicate is rejected. Actions are matched to candidates by this string. |
| `id` | yes | Identifies your source in Quidquid's log messages. |
| `label` | yes | LocalisedString shown as the source label on each result row. |
| `prefixes` | no | Prefix words that lock the palette to this source — with `{ "w", "widget" }`, typing `widget ` locks to it. A prefix already taken by another source is ignored with a log line, as is an empty string. |
| `in_default_search` | no | When true, the source takes part in the unlocked search. When false it is reachable only through a prefix. |
| `interface` | yes | Name of your remote interface implementing the functions below. |

### Interface functions

| Function | Required | Contract |
| --- | --- | --- |
| `search(query, player_index)` | yes | Returns an array of candidates. `query` is already whitespace-trimmed and may be empty. |
| `is_query_valid(query, player_index)` | no | Return `false` to mark the palette input as invalid for this query. Every searched source is asked; one `false` is enough. |

Results from all searched sources are merged by `search_score` (higher first,
ties broken by source registration order) and the top 30 rows are shown.

### Candidates

| Field | Required | Meaning |
| --- | --- | --- |
| `type` | yes | Must be the source's own `type`; this is what actions resolve on. |
| `id` | yes | Your identifier for the entry. Handed back to actions verbatim. |
| `label` | yes | String or LocalisedString naming the entry. |
| `icon` | yes | SpritePath, rendered as `[img=...]`. |
| `search_score` | yes | Ranking score, higher first. A candidate without a numeric one raises an error that aborts the entire search, not just that candidate. |
| `search_display_name` | no | Plain string shown instead of `label` as the name. Only a plain string can carry match highlighting. |
| `search_internal_name` | no | Plain string shown as the muted second line (Quidquid's own sources put the prototype name here). |
| `search_display_ranges`, `search_internal_ranges` | no | Arrays of tables with `start_byte` and `end_byte`, marking the matched part of the corresponding name in bold. |
| `secondary_text` | no | Muted second line for a candidate with no `search_internal_name`. |
| `numeric` | no | Right-align the name, for a candidate whose label is a value rather than a name. |
| `annotation` | no | A table with `caption` and `tooltip` LocalisedStrings. The caption is shown at the right end of the row, the tooltip above the action hints. |

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
| `is_available(player_index)` | no | Return `false` to hide the action. |

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

| File | Shows |
| --- | --- |
| [`lib/sources/calculator_source.lua`](lib/sources/calculator_source.lua) | The smallest source, plus `is_query_valid` and `secondary_text` |
| [`lib/sources/fluid_source.lua`](lib/sources/fluid_source.lua) | A prototype-backed source with a translation dictionary |
| [`lib/sources/item_source.lua`](lib/sources/item_source.lua) | Per-candidate `annotation` |
| [`lib/actions/open_factoriopedia_action.lua`](lib/actions/open_factoriopedia_action.lua) | The smallest action, acting on several types |
| [`lib/actions/temporary_request_action.lua`](lib/actions/temporary_request_action.lua) | `is_available` against player state |
