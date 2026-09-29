# Quidquid

[![Downloads](https://img.shields.io/badge/dynamic/json.svg?label=Downloads&url=https%3A%2F%2Fmods.factorio.com%2Fapi%2Fmods%2Fquidquid&query=%24.downloads_count)](https://mods.factorio.com/mod/quidquid)

Quidquid is a general-purpose palette with incremental search for Factorio,
over items, recipes, technologies and more. Each result offers the actions that
apply to it, and extension mods add further sources and actions. Open it with
`Ctrl/Cmd + K`.

## Features

- `Ctrl/Cmd + K` palette that searches items, fluids, recipes and technologies
- Fuzzy search over both the translated and the internal name, insensitive to
  case, accents and width
- Source-specific actions on the selected result
- Source prefixes to restrict a search to one category
- Temporary personal logistics requests for items and recipe ingredients,
  removed automatically once fulfilled

## Usage

### Opening and navigating

Press `Ctrl/Cmd + K` to open the palette. The search field takes focus and
results appear as you type. Hovering or clicking a result selects it.

`Enter` moves focus off the search field onto the selected result, after which
`J` and `K` step through the list. They only move the highlight — every action
is dispatched against the result under the cursor — and the default bindings are
all mouse combinations, so running an action means clicking the row you want.

The title bar holds a pin button and a cancel button. Pinning keeps the palette
open after an action runs and refreshes the results, so several actions can be
run in a row; the state is remembered until the save is loaded again. `Esc`
closes the palette.

Every key in this document except `Enter` and `Esc` is a Quidquid control and
can be rebound in Factorio's control settings.

### Searching

A query matches when its characters appear in order, not necessarily together,
so `emd` finds *electric mining drill*. Results rank by how tightly they
matched: consecutive characters and word beginnings score higher.

Both the translated name and the internal prototype name are searched, so
`iron-plate` works whatever the game language is. A hit on the translated name
outranks the same hit on the internal name.

Before matching, the query and the name are both folded, which makes these
differences invisible to the search:

- Case, and accents and other combining marks — `e` matches `é`, `u` matches `ü`
- Letters that are not a base plus a mark: `ß` → `ss`, `æ` → `ae`, `œ` → `oe`,
  `ø` → `o`, `ł` → `l`, `đ` → `d`
- Fullwidth forms and the ideographic space, folded to their ASCII equivalents
- Japanese: hiragana and katakana are the same for searching, and halfwidth
  katakana folds to fullwidth, dakuten and handakuten included
- Korean: a syllable breaks into the jamo that type it, so an initials-only
  query (`ㅊㅈ`) and a half-typed syllable both reach the finished word
- Arabic and Hebrew: vowel points, and the tatweel used to stretch a word

Under the Turkish locale, `I` folds to dotless `ı` and `İ` to `i`; under every
other locale both fold to `i`. Internal names are folded with no locale rule at
all, so they behave the same for every player.

Matched characters are highlighted where they sit in the name as it is written,
not in the folded form.

### Restricting the search to one source

A recognized prefix followed by a space locks the search to that source. Every
source accepts a one-letter abbreviation as well as its full name:

| Prefix | Source |
| --- | --- |
| `i ` / `item ` | Items |
| `f ` / `fluid ` | Fluids |
| `r ` / `recipe ` | Recipes |
| `t ` / `technology ` | Technologies |
| `= ` | Calculator |

While locked, another recognized prefix switches sources directly. The × next to
the source label unlocks again, as does a space typed into an empty field.

A prefix is matched exactly, case included, so `Item ` is an ordinary query even
though the search itself ignores case.

## Sources and actions

### Items

Search for items by name.

| Key | Action |
| --- | --- |
| Left click | Craft 1 |
| Right click | Craft 5 |
| `Shift` + left click | Craft all |
| `Ctrl/Cmd` + left click | Create a temporary logistics request |
| `Alt` + left click | Open in Factoriopedia |
| `Alt` + right click | Pipette |

Craft actions only use a recipe with the same name as the selected item. Rather
than fail silently, Quidquid reports why it cannot craft: no recipe of that
name, the recipe is not researched yet, it cannot be hand-crafted, or there are
not enough ingredients.

Each result shows the player's inventory count and, once personal logistics
requests are unlocked and the player is within a logistic network's range, that
network's stock. Hover a result for a per-quality breakdown and any items
currently in transit.

### Fluids

Search for fluids by name.

| Key | Action |
| --- | --- |
| `Alt` + left click | Open in Factoriopedia |

Known limitation: in English, a name starting with the word Fluid cannot be
typed in lowercase — the space after `fluid` completes the `fluid ` source
prefix and locks the palette to fluids. Prefixes are case-sensitive, so
`Fluid wagon` as it reads is unaffected, and so is `fluidwagon`.

### Recipes

Search for recipes by name. Craft actions use the number of crafting operations,
not the number of items produced by each operation, and are subject to the same
craftability checks as items.

| Key | Action |
| --- | --- |
| Left click | Craft 1 |
| Right click | Craft 5 |
| `Shift` + left click | Craft all |
| `Ctrl/Cmd` + left click | Create temporary logistics requests for recipe ingredients |
| `Alt` + left click | Open in Factoriopedia |
| `Alt` + right click | Pipette the recipe's item product, if it has exactly one |

### Technologies

Search for technologies by name.

| Key | Action |
| --- | --- |
| Left click | Add to the research queue |
| `Alt` + left click | Open the technology screen |

Missing prerequisites are queued ahead of the technology when there is enough
room; Factorio's research queue holds seven entries. Quidquid reports the
outcome either way — already queued or researched, the queue is full, there is
no room for the prerequisites, or the technology is unlocked by an in-game
trigger rather than by research and so cannot be queued at all.

Each result's state is color-coded: red for not yet researchable, orange for
researchable once its queued prerequisites finish, yellow for researchable now,
green for already researched. Hover a result for missing prerequisites, current
progress, and, for a technology unlocked by an in-game action, what that action
is.

### Surfaces, resources and blueprints

These sources live in their own mods:
[Quidquid: Surfaces](https://mods.factorio.com/mod/quidquid-surfaces),
[Quidquid: Resources](https://mods.factorio.com/mod/quidquid-resources) and
[Quidquid: Blueprints](https://mods.factorio.com/mod/quidquid-blueprints).

### Calculator

Evaluate an arithmetic expression with the `= ` prefix. The calculator is left
out of the default search, so the prefix is the only way to reach it.

Expressions are evaluated by the game's own expression parser. A number may
carry a `k` (thousand) or `M` (million) suffix in either case, as in the base
game's circuit network signal count entry. The result is shown to four decimal
places with trailing zeros trimmed, alongside a compact `k`/`M`/`B`/`T` form. An
expression that cannot be evaluated, or that does not produce a finite number,
yields no result. A calculator result has no actions.

## Temporary logistics requests

Select an item or recipe, enter the desired quantity, and confirm with the
button or with `E`.

For items the quantity is a number of items, and the +/- buttons round up to the
next whole stack and down to the previous one. For recipes it is a number of
crafting operations, adjusted one operation at a time, and the request covers
every item ingredient for that many operations. Where the Quality system is
available, the selected quality applies to the item, or to every ingredient of a
recipe.

Requests are stored separately from existing personal logistics requests and are
removed automatically once the requested amount is in the player's inventory.

## Settings

### Include hidden entries

Also list what the game itself keeps out of view: prototypes marked hidden, such
as internal items and recipes, and the upgrade-technology levels the technology
screen does not show as their own tile. Entries that are merely locked or not
researched yet are listed either way. Extension mods may honour the setting for
their own entries.

## Related mods

- [Quidquid: Blueprints](https://mods.factorio.com/mod/quidquid-blueprints) —
  blueprints, books and planners, to hold, copy or export.
- [Quidquid: Resources](https://mods.factorio.com/mod/quidquid-resources) —
  charted resource patches, to view, pin or look up.
- [Quidquid: Surfaces](https://mods.factorio.com/mod/quidquid-surfaces) —
  planets and space platforms, to open in remote view or look up.
- [Quidquid: Factory Search](https://mods.factorio.com/mod/quidquid-factory-search)
  — opens [Factory Search](https://mods.factorio.com/mod/FactorySearch) for the
  selected entry.
- [Factory Palette](https://mods.factorio.com/mod/factory-palette) — a command
  palette that also opens with `Ctrl/Cmd + K`.
- [Quicksearch](https://mods.factorio.com/mod/Quicksearch) — picks up or crafts
  from the inventory, chests, logistic networks and recipes;
  [Quicksearch Enhanced](https://mods.factorio.com/mod/quicksearch-enhanced)
  extends it for Factorio 2.1.
- [Quick Item Search](https://mods.factorio.com/mod/QuickItemSearch) — an item
  search for Factorio 1.1, the model for Quidquid's temporary requests.

## Extending Quidquid

Other mods can add their own search sources and palette actions by declaring
them as `mod-data` prototypes. See
[EXTENDING.md](https://github.com/sakuro/quidquid/blob/main/EXTENDING.md).

## License

Quidquid is licensed under the MIT License. See
[`LICENSE.txt`](https://github.com/sakuro/quidquid/blob/main/LICENSE.txt).

The fuzzy matching in
[`lib/fuzzy_match.lua`](https://github.com/sakuro/quidquid/blob/main/lib/fuzzy_match.lua)
is adapted from [fzy-lua](https://github.com/swarn/fzy-lua) by Seth Warn,
modified to operate on normalized UTF-8 code point sequences instead of bytes,
to return 1-based code point positions, and to score candidates for ranking
across search sources. It is separately licensed under the MIT License; see
[`LICENSE-fzy-lua.txt`](https://github.com/sakuro/quidquid/blob/main/LICENSE-fzy-lua.txt).

The calculator icon (`graphics/icons/calculator.png`) is derived from the
`calculator` icon of [Font Awesome Free](https://fontawesome.com/license/free)
(Copyright Fonticons, Inc., licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)). It was recolored
white and resized into mipmaps.
