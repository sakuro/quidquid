# Quidquid

[![Downloads](https://img.shields.io/badge/dynamic/json.svg?label=Downloads&url=https%3A%2F%2Fmods.factorio.com%2Fapi%2Fmods%2Fquidquid&query=%24.downloads_count)](https://mods.factorio.com/mod/quidquid)

Quidquid is a general-purpose palette with incremental search for Factorio.
Items, fluids, recipes, technologies and surfaces are searched together, and each
result offers the actions that apply to it. Open it with `Ctrl/Cmd + K`.

## Features

- `Ctrl/Cmd + K` palette that searches items, fluids, recipes, technologies,
  planets, and accessible space platforms together
- Source-specific actions on the selected result
- Source prefixes to restrict a search to one category
- Temporary personal logistics requests for items and recipe ingredients,
  removed automatically once fulfilled

## Usage

### Opening and navigating

Press `Ctrl/Cmd + K` to open the palette. The search field takes focus, and
results appear as you type. Hovering a result selects it.

To select with the keyboard, press `Enter` first: that moves focus off the
search field and onto the selected result, after which `J` and `K` step down and
up through the list.

`J` and `K` only move the highlight, though. Every action is dispatched against
the result under the cursor, and clicking a row also makes it the selected one,
so with the default bindings — all of them mouse combinations — running an
action means clicking the row you want.

The title bar holds a pin button and a cancel button. Pinning keeps the palette
open after an action runs, so several actions can be run in a row, and the
results refresh after each one; without it the palette closes as soon as an
action runs. The pin state is remembered until the save is loaded again. `Esc`
closes the palette.

Every key in this document except `Enter` and `Esc` is a Quidquid control and
can be rebound in Factorio's control settings.

### Restricting the search to one source

A recognized prefix followed by a space locks the search to that source. Every
source accepts a one-letter abbreviation as well as its full name:

| Prefix | Source |
| --- | --- |
| `i ` / `item ` | Items |
| `f ` / `fluid ` | Fluids |
| `r ` / `recipe ` | Recipes |
| `t ` / `technology ` | Technologies |
| `s ` / `surface ` | Surfaces |
| `= ` | Calculator |

While locked, typing another recognized prefix switches directly to that
source. To unlock and search across all sources again, click the × next to
the source label, or type a space with the search field empty.

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
requests are unlocked and the player is within a logistic network's range,
that network's stock. Hover a result for a per-quality breakdown and any
items currently in transit to or from the player.

### Fluids

Search for fluids by name.

| Key | Action |
| --- | --- |
| `Alt` + left click | Open in Factoriopedia |

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
researchable once its queued prerequisites finish, yellow for researchable
now, green for already researched. Hover a result for missing prerequisites,
current progress, and — for a technology unlocked by an in-game action rather
than research — what that action is.

### Surfaces

Search for planets and space platforms available to your force. A platform
owned by another force is listed with that force's name.

| Key | Action |
| --- | --- |
| Left click | Open in remote view |
| `Alt` + left click | Open in Factoriopedia |

Remote view opens at the position you last occupied on that surface, whether in
person or in remote view. Without such a position it opens at the space
platform's hub, or at your force's spawn position on a planet.

Remote view also needs the planet to be unlocked by your force and its surface
to be generated; Quidquid says which of the two is missing. Factoriopedia works
for a locked or ungenerated planet either way.

Space platforms are listed when owned by your force or when their owner
considers your force a friend. Rich text tags in a platform's name (an icon,
say) aren't searchable, so a platform named with only a tag and no other text
can't be found by query. Space locations such as Solar System Edge are not
surfaces and are not included.

### Calculator

Evaluate an arithmetic expression with the `= ` prefix. The calculator is left
out of the unlocked search, so the prefix is the only way to reach it.

Expressions are evaluated by the game's own expression parser. A number may
carry a `k` (thousand) or `M` (million) suffix in either case, as in the base
game's circuit network signal count entry. The result is shown to four decimal
places with trailing zeros trimmed, alongside a compact `k`/`M`/`B`/`T` form. An
expression that cannot be evaluated, or that does not produce a finite number,
yields no result.

A calculator result has no actions.

## Temporary logistics requests

Select an item or recipe, enter the desired quantity, and confirm with the
button or with `E`.

For items, the quantity is the requested number of items, and the +/- buttons
round up to the next whole stack and down to the previous one. For recipes, the
quantity is the number of crafting operations and the +/- buttons adjust it by
one operation; the request then covers every item ingredient for that many
operations. Where the Quality system is available, the selected quality applies
to the item, or to every ingredient of a recipe.

Requests are stored separately from existing personal logistics requests and
are removed automatically once the requested amount is in the player's
inventory.

## Settings

### Include hidden entries

Show hidden or internal entries in search results. It applies to every source
that searches prototypes: items, fluids, recipes, technologies and surfaces.

## Extending Quidquid

Other mods can add their own search sources and palette actions through
Quidquid's remote interface. See
[EXTENDING.md](https://github.com/sakuro/quidquid/blob/main/EXTENDING.md).

## Third-party software

The fuzzy matching implementation in
[`lib/fuzzy_match.lua`](https://github.com/sakuro/quidquid/blob/main/lib/fuzzy_match.lua)
is adapted from [fzy-lua](https://github.com/swarn/fzy-lua) by Seth Warn.

Quidquid modifies the implementation to:

- operate on normalized UTF-8 code point sequences instead of bytes
- return 1-based code point positions for matched characters
- integrate with Quidquid's multilingual search normalization
- provide scores for ranking candidates across search sources

fzy-lua is distributed under the MIT License. The applicable license text is
included in
[`LICENSE-fzy-lua.txt`](https://github.com/sakuro/quidquid/blob/main/LICENSE-fzy-lua.txt).

## License

Quidquid is licensed under the MIT License. See
[`LICENSE.txt`](https://github.com/sakuro/quidquid/blob/main/LICENSE.txt).

The adapted fzy-lua implementation is separately licensed under the MIT
License. See
[`LICENSE-fzy-lua.txt`](https://github.com/sakuro/quidquid/blob/main/LICENSE-fzy-lua.txt).

The calculator icon (`graphics/icons/calculator.png`) is derived from the
`calculator` icon of [Font Awesome Free](https://fontawesome.com/license/free)
(Copyright Fonticons, Inc., licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)). It was recolored
white and resized into mipmaps.
