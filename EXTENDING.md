# Extending Quidquid

> **Draft.** Written from Quidquid's own implementation, not yet verified by
> building a mod against it. Expect gaps and mistakes; check the code, or open an
> issue, when something here does not match what you see.

Other mods can add their own search sources and palette actions. A mod declares
each one as a `mod-data` prototype in the data stage and implements its behavior
in a remote interface of its own — no change to Quidquid itself is needed, and
your code keeps running in your own mod.

The contract is versioned with `contract_version`, currently `4`. A declaration
whose `contract_version` does not match is skipped, so a future bump disables it
until you update. Until Quidquid reaches 1.0, expect the contract to change
without a compatibility shim.

## Depending on Quidquid

A declaration is plain data: without Quidquid installed, nothing reads it. An
optional dependency (`? quidquid` in `info.json`) is therefore enough, and neither
the declaration nor your remote interface needs a guard. Requiring
`__quidquid__.lib.api` (see [Scoring](#scoring)) is the exception: it needs
Quidquid as a hard dependency.

## Declaring

Declare in `data.lua` or `data-updates.lua`. Each source or action is one
`mod-data` prototype:

| Field | Required | Meaning |
| --- | --- | --- |
| `type` | yes | `"mod-data"`. |
| `name` | yes | Identifies the source or action in Quidquid's log messages. Prefix it with your mod name. |
| `data_type` | yes | `"quidquid.source"` or `"quidquid.action"`. |
| `order` | no | Registration order, compared as a string with ties broken by `name`. It decides which candidate goes first on an equal `search_score`, and which declaration keeps a prefix or an action slot that two of them claim. Quidquid's own sources use `"a"` to `"f"`; omitted, it is the empty string, which sorts first. |
| `data` | yes | The definition described under [Sources](#definition) or [Actions](#definition-1), including `contract_version`. |

Quidquid checks every declaration for its own contract version in its
`data-final-fixes.lua`, and a malformed one stops the game at startup with an
error naming the declaration. A mod that depends on Quidquid runs its own
`data-final-fixes.lua` after that check, so a change made there is not validated.

Add the remote interface that `data.interface` names from your `control.lua`'s
main chunk. Quidquid reads the declarations there too, so every source and
action is in place before the first event.

## Sources

A source answers search queries with candidates of one type.

### Definition

The `data` of a `quidquid.source` declaration:

| Field | Required | Meaning |
| --- | --- | --- |
| `contract_version` | yes | Must be `4`. |
| `type` | yes | The candidate type this source produces. Unique across all sources — a later declaration for a type already taken is skipped with a log line. Actions are matched to candidates by this string. |
| `label` | yes | LocalisedString shown as the source label on each result row. |
| `prefixes` | no | Prefix words that lock the palette to this source — with `{ "w", "widget" }`, typing `widget ` locks to it. Matched case-sensitively, so `W` and `w` are separate prefixes and either may be claimed on its own. A prefix already taken by an earlier declaration is ignored with a log line. Defaults to none. |
| `interface` | yes | Name of your remote interface implementing the functions below. |

Whether a source takes part in the unlocked search is not part of this table —
see [Default search](#default-search).

### Interface functions

| Function | Required | Contract |
| --- | --- | --- |
| `search(query, player_index)` | yes | Returns an array of candidates. `query` is already whitespace-trimmed and may be empty. |
| `is_query_valid(query, player_index)` | no | Return `false` to mark the palette input as invalid for this query. Every searched source is asked; one `false` is enough. Omitted, every query is valid. |
| `decorate(candidates, player_index)` | no | Refines the candidates that survived the merge and trim, described below. |

Results from all searched sources are merged by `search_score` (higher first,
ties broken by source registration order) and the top 30 rows are shown.

### Refining displayed candidates

`search` runs over every match; `decorate` runs only over the rows about to be shown,
after the merge and the trim to 30. Set a candidate's presentational fields
(`annotation`, `label`, `search_display_name`, ...) directly in `search` when computing
them is cheap per match. Implement `decorate` instead when the per-candidate cost scales
with the match count rather than with what's displayed — for example, a check that walks
world state or runs a spatial query, where a query with hundreds of matches would
otherwise pay that cost hundreds of times to show 30 rows.

```
decorate(candidates, player_index) -> decorations
```

- Called once per source per render, with only that source's displayed candidates —
  the same batching `is_query_valid` and `search` get, not once per row.
- Detected with `RemoteCaller:has(interface, "decorate")`, so it is optional and needs
  no `contract_version` bump.
- `candidates` is the array of this source's own candidates among the rows about to be
  shown, in display order. Returns an array of the same length: element `i` is either
  `nil` (leave candidate `i` alone) or a table of fields to merge into it.
- Every key in a returned table is merged into the candidate **except** `type`, `id`
  and `search_score` — those are silently ignored, even if present, since they are
  identity and ranking rather than presentation: actions resolve on `type` and `id`,
  and `search_score` has already been used to order the rows on screen.
- `decorate` runs after `search`, so a field it sets wins over whatever `search` put
  there for that candidate.
- A source whose `decorate` call raises is logged and its candidates are left exactly
  as `search` produced them, the same as a broken `is_query_valid` or `search`.

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
| `search_internal_prefix` | no | LocalisedString shown before `search_internal_name` on the second line, as is — include any separator. Neither searched nor highlighted. Ignored without a `search_internal_name`. |
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

### Rich text in names

A name the player writes may carry rich-text tags, such as a blueprint called
`[item=rail]Main line`. `quidquid.rich_text.searchable(value)` returns the text
a search should see — tags read as what they name, `rail` here — and, for each
of its bytes, the original byte it came from. Match against that text, then pass
the ranges and those origins to `quidquid.rich_text.map_ranges(ranges, origins)`
for ranges over the original name, with tag-derived bytes left unhighlighted.

For a source that shows amounts, `quidquid.number_format.suffixed(value)` formats a
number the way Quidquid's own rows do.

### Shared settings

A source may honour Quidquid's `quidquid-include-hidden` setting, a runtime
per-user boolean read as `player.mod_settings["quidquid-include-hidden"].value`.
When it is false, leave out what the game keeps out of the player's view — for
a prototype, `hidden` set. Entries that are merely locked or not yet researched
are not hidden in this sense and stay listed. The setting's name and type are
part of the contract.

### Default search

Whether your source takes part in the unlocked search is a per-player setting
named `<declaration name>-default-search` — for the `my-mod-widgets` declaration
below, `my-mod-widgets-default-search`. It must be a `bool-setting` with
`setting_type = "runtime-per-user"`; `default_value = true` is recommended, so
a player sees your source without having to opt in. Declare it in
`settings.lua`:

```lua
data:extend({
  {
    type = "bool-setting",
    name = "my-mod-widgets-default-search",
    setting_type = "runtime-per-user",
    default_value = true,
  },
})
```

With locale keys for its name and description:

```ini
[mod-setting-name]
my-mod-widgets-default-search=...

[mod-setting-description]
my-mod-widgets-default-search=...
```

A source declared with no such setting is prefix-only: it registers normally
but never joins the default search. A source with neither `prefixes` nor the
setting is rejected at registration (see [Rejections and
failures](#rejections-and-failures)).

### Minimal example

In `data.lua`, with the setting above:

```lua
data:extend({
  {
    type = "mod-data",
    name = "my-mod-widgets",
    data_type = "quidquid.source",
    data = {
      contract_version = 4,
      type = "my-mod-widget",
      label = { "my-mod.source-widgets" },
      prefixes = { "w", "widget" },
      interface = "my-mod-widget-source",
    },
  },
})
```

In `control.lua`:

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
```

## Actions

An action is a key binding that runs against the selected candidate, for every
candidate type it declares. It may act on types owned by other mods, including
Quidquid's own (`item`, `fluid`, `recipe`, `technology`, `calculation`).

### Quidquid's candidate types

An action on Quidquid's own types can rely on these fields besides the ones
under [Candidates](#candidates). Any other field is internal and may change
without a `contract_version` bump.

| Type | `id` | Other fields |
| --- | --- | --- |
| `item`, `fluid`, `recipe`, `technology` | The prototype name | |
| `calculation` | Opaque | |

### Definition

The `data` of a `quidquid.action` declaration:

| Field | Required | Meaning |
| --- | --- | --- |
| `contract_version` | yes | Must be `4`. |
| `types` | yes | Non-empty array of candidate types this action applies to. |
| `label` | yes | LocalisedString naming the action in the candidate tooltip. |
| `hint` | yes | LocalisedString for the key binding shown after the label — see [Tooltip hint](#tooltip-hint). |
| `input_name` | yes | Name of a custom-input prototype, which must exist by the startup check. Quidquid registers the event handler for it. One action per type and `input_name`; for a pair two declarations claim, the later one is ignored with a log line. |
| `interface` | yes | Name of your remote interface implementing the functions below. |

### Interface functions

| Function | Required | Contract |
| --- | --- | --- |
| `execute(candidate, player_index)` | yes | Performs the action on the selected candidate. May return a message to show the player — see [Messages](#messages). |
| `is_available(player_index)` | no | Return `false` to hide the action. Omitted, the action is always offered for its types. |

`is_available` may only gate on state that is uniform across every candidate of a
type, such as the player's own state. Whether one particular candidate can be
acted on is a fact for `execute` to resolve and report to the player — hiding it
in `is_available` removes the action from the tooltip without saying why.

### Messages

`execute` may return a message: a table whose first element is a locale key,
followed by that string's own parameters. Quidquid shows it as flying text at
the cursor, with the candidate's icon and label put in front of your
parameters — in the locale string `__1__` is the icon, `__2__` the label, and
your first parameter is `__3__`. Return `nil` to show nothing.

A LocalisedString holds at most 20 parameters, so a message carries at most 18
of its own. Each parameter must itself be a valid LocalisedString.

### Resolving before acting

Quidquid's own actions share one shape, which `lib/api.lua` offers as
`quidquid.run_action(candidate, player_index, resolve_fn, apply_fn, fallback_locale_key)`,
to be returned from `execute`:

- `resolve_fn(candidate, player)` returns what to act on, or `nil` and a locale
  key saying why not.
- On `nil`, `run_action` returns `{ locale_key }` (or `{ fallback_locale_key }`
  when `resolve_fn` gave none) as the message.
- Otherwise it returns whatever `apply_fn(payload, candidate, player)` returns —
  a message, or `nil`.
- A player that no longer exists gives `nil` without calling either.

### Shared inputs

Two of Quidquid's inputs are meant to be reused by other mods. Declare an action
for your own candidate type with one of them as its `input_name`, and use the same
`label` and `hint`. The player then has one binding and one wording for the idea,
whichever mod handles the type.

| `input_name` | `label` | `hint` |
| --- | --- | --- |
| `quidquid-open-factoriopedia` | `{ "quidquid.action-open-factoriopedia" }` | `{ "quidquid.action-open-factoriopedia-hint" }` |
| `quidquid-open-remote-view` | `{ "quidquid.action-open-remote-view" }` | `{ "quidquid.action-open-remote-view-hint" }` |

Quidquid itself declares no action on `quidquid-open-remote-view`; the input exists
for extensions.

Keep failure messages in your own locale: only the input and these keys are shared.

### Tooltip hint

The tooltip line for an action reads `<label> (<hint>)`. The engine only
substitutes `__CONTROL__<input>__` with the player's key binding in text that comes
from a locale file, so `hint` has to name a locale key rather than carry the text
itself:

```ini
[my-mod]
action-do-thing-hint=__CONTROL__my-mod-do-thing__
```

### Minimal example

In `data.lua`, next to the `my-mod-do-thing` custom-input:

```lua
data:extend({
  {
    type = "mod-data",
    name = "my-mod-do-thing",
    data_type = "quidquid.action",
    data = {
      contract_version = 4,
      types = { "my-mod-widget", "item" },
      label = { "my-mod.action-do-thing" },
      hint = { "my-mod.action-do-thing-hint" },
      input_name = "my-mod-do-thing",
      interface = "my-mod-do-thing-action",
    },
  },
})
```

In `control.lua`:

```lua
local function execute(candidate, _player_index)
  return { "my-mod.action-do-thing-done", candidate.id }
end

remote.add_interface("my-mod-do-thing-action", { execute = execute })
```

With, in the locale file:

```ini
[my-mod]
action-do-thing-done=Did the thing to __1__ __2__ (__3__)
```

## Rejections and failures

A mistake inside one declaration — a missing or mistyped field, an empty prefix,
an `input_name` with no custom-input — stops the game at startup (see
[Declaring](#declaring)). What depends on which mods are installed together is
not fatal: a declaration for another `contract_version`, or one whose `type`
another source already owns, is skipped with a line in the Factorio log, and a
prefix or type/`input_name` pair already taken is skipped while the rest of the
declaration still registers.

A source's default-search setting (see [Default search](#default-search)) is
also checked at registration rather than at startup, since a mod setting cannot
be read in the data stage. Both are log lines, not startup errors: a setting of
that name existing under the wrong type or `setting_type` rejects the source
outright, and so does a source with neither prefixes nor that setting — it
could never be reached.

Quidquid calls `search`, `is_query_valid`, `execute` and `is_available` through
`pcall`. An error inside them is logged and treated as no results, a valid query,
nothing done, or unavailable respectively — so a broken source or action looks
silently inert in game. A message from `execute` that is not a table starting
with a string, that carries more than 18 parameters, or that the engine
rejects as a LocalisedString, is logged and not shown. Check the log.

## Translated names

Quidquid's translated prototype names are not shared — flib's dictionary state
lives in each mod's own `storage`. A source that matches on translated names
keeps its own dictionary. With flib, create it from `on_init` and
`on_configuration_changed`, which have to run before flib's first `on_tick`.

## Reference implementations

These are Quidquid's own sources and actions, shown as examples. Apart from
`lib/api.lua`, nothing under `lib/` is a public API — read them, don't require
them.

| File | Shows |
| --- | --- |
| [`prototypes/sources.lua`](prototypes/sources.lua), [`prototypes/actions.lua`](prototypes/actions.lua) | The declarations of all of them |
| [`lib/sources/calculator_source.lua`](lib/sources/calculator_source.lua) | The smallest source, plus `is_query_valid` and `secondary_text` |
| [`lib/sources/fluid_source.lua`](lib/sources/fluid_source.lua) | A prototype-backed source with a translation dictionary |
| [`lib/sources/item_source.lua`](lib/sources/item_source.lua) | Per-candidate `annotation` |
| [`lib/actions/open_factoriopedia_action.lua`](lib/actions/open_factoriopedia_action.lua) | The smallest action, acting on several types |
| [`lib/actions/temporary_request_action.lua`](lib/actions/temporary_request_action.lua) | `is_available` against player state |
| [`lib/actions/research_queue_action.lua`](lib/actions/research_queue_action.lua) | Returning a message on success and on failure |
