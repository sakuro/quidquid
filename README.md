# Quidquid

[![Downloads](https://img.shields.io/badge/dynamic/json.svg?label=Downloads&url=https%3A%2F%2Fmods.factorio.com%2Fapi%2Fmods%2Fquidquid&query=%24.downloads_count)](https://mods.factorio.com/mod/quidquid)

Quidquid is a command palette for Factorio. Open it with `Ctrl/Cmd + K` to
search available entries and perform actions on the selected result.

## Features

- Ctrl/Cmd + K command palette for searching and acting on items, fluids, recipes,
  technologies, planets, and accessible space platforms
- Source-specific actions including Factoriopedia, technology screens, remote view,
  crafting, and research-queue management
- Technology research actions queue missing prerequisites when there is enough room
- Recognized source prefixes, such as `item `, `fluid `, `recipe `, `technology `,
  and `surface `, to restrict searches by category
- Temporary personal logistics requests for items and recipe ingredients, with
  quantity expressions, stack adjustment buttons, and quality selection
- Automatic removal of temporary requests once they are fulfilled
- Item results show the player's inventory count and, once connected to a
  logistic network, its stock of that item
- Technology results show research state (not researched, available,
  researched) and, for a research trigger, what completes it
- Position history for remote surface views

## Usage

Press `Ctrl/Cmd + K` to open the command palette.

Type a search query to find matching entries. A recognized prefix followed by a
space locks the search to that source. For example:

- `item `
- `fluid `
- `recipe `
- `technology `
- `surface `

While locked, typing another recognized prefix switches directly to that
source. To unlock and search across all sources again, click the × next to
the source label, or type a space with the search field empty.

Select a result and use the available action keys shown in the palette.

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

Item craft actions only use a recipe with the same name as the selected item.
If no such recipe exists, Quidquid displays a message instead of attempting to
craft the item.

Each result shows the player's inventory count and, once personal logistics
requests are unlocked and the player is within a logistic network's range,
that network's stock. Hover a result for a per-quality breakdown and any
items currently in transit to or from the player.

### Fluids

Search for fluids by name. The only available action is opening the fluid in Factoriopedia.


### Technologies

Search for technologies by name.

| Key | Action |
| --- | --- |
| Left click | Add to the research queue |
| Alt + left click | Open in Factoriopedia |

Technologies can also be added to the research queue with left click. Missing
prerequisites are queued first when there is enough room.

Each result's state is color-coded: red for not yet researchable, orange for
researchable once its queued prerequisites finish, yellow for researchable
now, green for already researched. Hover a result for missing prerequisites,
current progress, and — for a technology unlocked by an in-game action rather
than research — what that action is.

### Recipes

Search for recipes by name. Craft actions use the number of crafting operations,
not the number of items produced by each operation.

| Key | Action |
| --- | --- |
| Left click | Craft 1 |
| Right click | Craft 5 |
| `Shift` + left click | Craft all |
| `Ctrl/Cmd` + left click | Create temporary logistics requests for recipe ingredients |
| `Alt` + left click | Open in Factoriopedia |
| `Alt` + right click | Pipette the recipe's item product, if it has exactly one |

### Surfaces

Search for planets and space platforms available to your force.

| Key | Action |
| --- | --- |
| Left click | Open in remote view |
| `Alt` + left click | Open in Factoriopedia |

## Temporary logistics requests

Select an item or recipe, enter the desired quantity, and confirm the request.

For items, the quantity is the requested number of items and the +/- buttons
adjust it by whole item stacks. For recipes, the quantity is the number of
crafting operations and the +/- buttons adjust it by one operation. Recipe
requests include all item ingredients for the selected number of operations, with
the selected quality applied to every ingredient.

Requests are stored separately from existing personal logistics requests and
are removed automatically when the requested amount is available in the
player's inventory.

The request editor also supports stack-based quantity adjustment and item
quality selection when the Quality system is available.

## Surface search limitations

- Remote view requires the planet surface to be generated and the planet to be
  unlocked by your force.
- Planets without generated surfaces can still be opened in Factoriopedia.
- Locked planets can still be opened in Factoriopedia.
- Space platforms are included when owned by your force or when their owner
  considers your force a friend.
- Rich text tags in a platform's name (e.g. an icon) aren't searchable; a
  platform named with only a tag and no other text can't be found by query.
- Space locations such as Solar System Edge are not included because they are
  not surfaces.

## Settings

### Include hidden entries

Show hidden or internal entries in search results.

## Third-party software

The fuzzy matching implementation in
[`lib/fuzzy_match.lua`](lib/fuzzy_match.lua) is adapted from
[fzy-lua](https://github.com/swarn/fzy-lua) by Seth Warn.

Quidquid modifies the implementation to:

- operate on normalized UTF-8 code point sequences instead of bytes
- return 1-based code point positions for matched characters
- integrate with Quidquid's multilingual search normalization
- provide scores for ranking candidates across search sources

fzy-lua is distributed under the MIT License. The applicable license text is
included in [`LICENSE-fzy-lua.txt`](LICENSE-fzy-lua.txt).

## License

Quidquid is licensed under the MIT License. See
[`LICENSE.txt`](LICENSE.txt).

The adapted fzy-lua implementation is separately licensed under the MIT
License. See [`LICENSE-fzy-lua.txt`](LICENSE-fzy-lua.txt).

The calculator icon (`graphics/icons/calculator.png`) is derived from the
`calculator` icon of [Font Awesome Free](https://fontawesome.com/license/free)
(Copyright Fonticons, Inc., licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)). It was recolored
white and resized into mipmaps.
