local BlueprintLogic = {}

local MISSING_ICON = "utility/missing_icon"
local PATH_SEPARATOR = " › "
local LOCATIONS = { my = true, game = true, inv = true }

--- A signal's SpritePath.
---
--- SignalID reads `type` as nil for items, and names virtual signals `virtual` while
--- their sprite class is `virtual-signal`; every other SignalIDType is its own class.
---@param signal table|nil  a SignalID
---@return string|nil  nil for a missing signal or one without a name
function BlueprintLogic.sprite_path(signal)
  if signal == nil or signal.name == nil then
    return nil
  end
  local signal_type = signal.type or "item"
  if signal_type == "virtual" then
    signal_type = "virtual-signal"
  end
  return signal_type .. "/" .. signal.name
end

--- A record's preview icons as one rich text string, in the library's order.
---
--- An icon whose prototype no longer exists becomes the engine's own missing-icon
--- question mark rather than disappearing, so the count and order still match what
--- the library shows.
---@param icons table|nil  array of BlueprintSignalIcon
---@param is_valid_sprite_path function  (path) -> boolean; the runtime check
---@return string|nil  nil when there is nothing to show
function BlueprintLogic.icon_caption(icons, is_valid_sprite_path)
  local sorted = {}
  for _, icon in pairs(icons or {}) do
    table.insert(sorted, icon)
  end
  table.sort(sorted, function(a, b)
    return a.index < b.index
  end)
  local parts = {}
  for _, icon in ipairs(sorted) do
    local path = BlueprintLogic.sprite_path(icon.signal)
    if path ~= nil then
      if not is_valid_sprite_path(path) then
        path = MISSING_ICON
      end
      table.insert(parts, "[img=" .. path .. "]")
    end
  end
  if #parts == 0 then
    return nil
  end
  return table.concat(parts)
end

--- A candidate id: the location and the index path down to the entry.
---@param location string  "my", "game" or "inv"
---@param indices table  array of integers
---@return string
function BlueprintLogic.format_id(location, indices)
  local parts = { location }
  for _, index in ipairs(indices) do
    table.insert(parts, tostring(index))
  end
  return table.concat(parts, "/")
end

--- Splits a candidate id back into its location and index path.
---@param id string
---@return string|nil  the location, nil for a malformed id
---@return table|nil  array of integers
function BlueprintLogic.parse_id(id)
  local location, rest = id:match("^(%a+)/([%d/]+)$")
  if location == nil or not LOCATIONS[location] or rest:sub(-1) == "/" or rest:find("//", 1, true) then
    return nil, nil
  end
  local indices = {}
  for part in rest:gmatch("[^/]+") do
    table.insert(indices, tonumber(part))
  end
  return location, indices
end

--- One book's label shrunk to a single unit, for the abbreviated part of a path.
---
--- A label that opens with an icon keeps that icon, which identifies the book better
--- than any one character would; color and font tags carry no identity, so they are
--- looked past.
---@param label string
---@return string  empty when the label has neither an icon nor text
function BlueprintLogic.abbreviate(label)
  local tag = label:match("^%b[]")
  if tag ~= nil then
    local name = tag:match("^%[([^=%]]*)")
    if name ~= "color" and name ~= "font" then
      return tag
    end
  end
  local stripped = label:gsub("%b[]", "")
  return stripped:match("^[\1-\127\194-\244][\128-\191]*") or ""
end

--- The enclosing books' labels as a full path and an abbreviated one for display.
---
--- Lua cannot measure rendered width, and the engine truncates an overflowing label
--- at its end -- which would cut off the nearest book first -- so the displayed path
--- is always abbreviated: the nearest book in full, each one before it as a single
--- unit. The two `_start` bytes locate the nearest book's label in each string, so
--- match ranges over the full path can be carried onto the displayed one.
---@param labels table  array of labels, outermost first
---@return table|nil  { full, display, full_start, display_start }; nil for no books
function BlueprintLogic.book_path(labels)
  if #labels == 0 then
    return nil
  end
  local nearest = labels[#labels]
  local units = {}
  for i = 1, #labels - 1 do
    local unit = BlueprintLogic.abbreviate(labels[i])
    if unit ~= "" then
      table.insert(units, unit)
    end
  end
  local full = table.concat(labels, PATH_SEPARATOR)
  local display_prefix = #units > 0 and (table.concat(units, PATH_SEPARATOR) .. PATH_SEPARATOR) or ""
  return {
    full = full,
    display = display_prefix .. nearest,
    full_start = #full - #nearest + 1,
    display_start = #display_prefix + 1,
  }
end

-- Fills in what records and blueprint-like items share under the same attribute
-- names. Each description attribute exists only on its own kinds, and
-- default_icons only on a blueprint; reading one elsewhere raises.
local function describe(node, source)
  if node.type == "blueprint" or node.type == "blueprint-book" then
    node.description = source.blueprint_description
  else
    node.description = source.planner_description
  end
  if node.type == "blueprint" and (node.icons == nil or next(node.icons) == nil) then
    node.icons = source.default_icons
  end
end

local function record_node(key, record)
  local node = { key = key, type = record.type, label = record.label, icons = record.preview_icons }
  -- A preview record has not been downloaded yet; only what the library itself
  -- shows before download (label, preview icons) is read from it.
  if not record.is_preview then
    describe(node, record)
    if node.type == "blueprint-book" then
      node.children = BlueprintLogic.to_nodes(record.contents)
    end
  end
  return node
end

--- Converts library records into plain nodes, walking books.
---
--- `contents` is a sparse array, so keys are collected with pairs and sorted rather
--- than read with `#`.
---@param records table  array or sparse table of LuaRecord
---@return table  array of { key, type, label, icons, description, children }
function BlueprintLogic.to_nodes(records)
  local nodes = {}
  for key, record in pairs(records) do
    if record.valid then
      table.insert(nodes, record_node(key, record))
    end
  end
  table.sort(nodes, function(a, b)
    return a.key < b.key
  end)
  return nodes
end

--- The record type a blueprint-like item corresponds to.
---
--- An item's `type` is its prototype type, which names planners
--- `deconstruction-item` and `upgrade-item`; the `is_*` flags are read instead so
--- inventory entries use the same vocabulary as library records.
---@param stack LuaItemStack  valid for read
---@return string|nil  nil for any other item
function BlueprintLogic.item_kind(stack)
  if stack.is_blueprint then
    return "blueprint"
  elseif stack.is_blueprint_book then
    return "blueprint-book"
  elseif stack.is_deconstruction_item then
    return "deconstruction-planner"
  elseif stack.is_upgrade_item then
    return "upgrade-planner"
  end
  return nil
end

--- Converts the blueprint-like items of an inventory into plain nodes, walking
--- book items through their inner inventory.
---@param inventory LuaInventory
---@param item_main defines.inventory  `defines.inventory.item_main`
---@return table  array of { key, type, item_name, label, icons, description, children }
function BlueprintLogic.item_nodes(inventory, item_main)
  local nodes = {}
  for slot = 1, #inventory do
    local stack = inventory[slot]
    if stack.valid_for_read then
      local kind = BlueprintLogic.item_kind(stack)
      if kind ~= nil then
        local node =
          { key = slot, type = kind, item_name = stack.name, label = stack.label, icons = stack.preview_icons }
        describe(node, stack)
        if kind == "blueprint-book" then
          local inner = stack.get_inventory(item_main)
          node.children = inner ~= nil and BlueprintLogic.item_nodes(inner, item_main) or {}
        end
        table.insert(nodes, node)
      end
    end
  end
  return nodes
end

--- Finds a library record again by its index path, for an action to run on.
---
--- The library can change between the search and the action, so the record must
--- still have the type and label the candidate was built from; a preview record is
--- refused because it cannot be exported yet.
---@param roots table  the shelf's top-level records
---@param indices table  array of integers
---@param record_type string
---@param label string
---@return LuaRecord|nil
function BlueprintLogic.resolve(roots, indices, record_type, label)
  local current = roots[indices[1]]
  for i = 2, #indices do
    if current == nil or not current.valid or current.type ~= "blueprint-book" or current.is_preview then
      return nil
    end
    current = current.contents[indices[i]]
  end
  if
    current == nil
    or not current.valid
    or current.is_preview
    or current.type ~= record_type
    or current.label ~= label
  then
    return nil
  end
  return current
end

--- Finds an inventory item again by its slot path, for an action to run on.
---
--- Slots are checked against the inventory size first: indexing a LuaInventory
--- past its end raises rather than returning nil.
---@param inventory LuaInventory
---@param indices table  array of slot numbers
---@param item_main defines.inventory  `defines.inventory.item_main`
---@param record_type string
---@param label string
---@return LuaItemStack|nil
function BlueprintLogic.resolve_item(inventory, indices, item_main, record_type, label)
  local current = inventory
  local found = nil
  for i, slot in ipairs(indices) do
    if i > 1 then
      if found.is_blueprint_book ~= true then
        return nil
      end
      current = found.get_inventory(item_main)
      if current == nil then
        return nil
      end
    end
    if slot > #current then
      return nil
    end
    found = current[slot]
    if not found.valid_for_read then
      return nil
    end
  end
  if found == nil or BlueprintLogic.item_kind(found) ~= record_type or found.label ~= label then
    return nil
  end
  return found
end

return BlueprintLogic
