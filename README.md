# Quidquid

[![Downloads](https://img.shields.io/badge/dynamic/json.svg?label=Downloads&url=https%3A%2F%2Fmods.factorio.com%2Fapi%2Fmods%2Fquidquid&query=%24.downloads_count)](https://mods.factorio.com/mod/quidquid)

Quidquid is a command palette for Factorio. Open it with `Ctrl/Cmd + K` to
search available entries and perform actions on the selected result.

## Features

- Fuzzy search with optional source prefixes
- Keyboard- and mouse-driven actions
- Source-specific actions for search results
- Recipe search and recipe-based crafting
- Temporary personal logistics requests
- Position history for remote surface views

## Usage

Press `Ctrl/Cmd + K` to open the command palette.

Type a search query to find matching entries. A recognized prefix followed by a
space restricts the search to that source. For example:

- `item `
- `recipe `
- `technology `
- `surface `

Select a result and use the available action keys shown in the palette.

## Sources and actions

### Items

Search for items by name.

| Key | Action |
| --- | --- |
| Left click | Craft 1 |
| Middle click | Craft 5 |
| `Shift` + left click | Craft all |
| `Ctrl/Cmd` + left click | Create a temporary logistics request |
| `Alt` + left click | Open in Factoriopedia |

### Technologies

Search for technologies by name.

| Key | Action |
| --- | --- |
| Left click | Open the technology screen |

### Recipes

Search for recipes by name. Craft actions use the number of crafting operations,
not the number of items produced by each operation.

| Key | Action |
| --- | --- |
| Left click | Craft 1 |
| Middle click | Craft 5 |
| `Shift` + left click | Craft all |
| `Ctrl/Cmd` + left click | Create temporary logistics requests for recipe ingredients |
| `Alt` + left click | Open in Factoriopedia |

Item craft actions only use a recipe with the same name as the selected item.
If no such recipe exists, Quidquid displays a message instead of attempting to
craft the item.

### Surfaces

Search for generated planets and space platforms available to your force.

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

- Ungenerated surfaces are not included.
- Remote view requires the planet to be unlocked by your force.
- Locked planets can still be opened in Factoriopedia.
- Space platforms are included when owned by your force or when their owner
  considers your force a friend.
- Space locations such as Solar System Edge are not included because they are
  not surfaces.

## Settings

### Include hidden entries

Show hidden or internal entries in search results.

## License

MIT License
