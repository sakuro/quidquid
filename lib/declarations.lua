-- Sources and actions are declared as mod-data prototypes. A prototype is readable
-- from control.lua's main chunk, so the registry is complete before any event fires,
-- and a malformed declaration stops the game at startup. See EXTENDING.md
-- "Declaring".

local Declarations = {}

Declarations.CONTRACT_VERSION = 2
Declarations.SOURCE_DATA_TYPE = "quidquid.source"
Declarations.ACTION_DATA_TYPE = "quidquid.action"

local KIND_BY_DATA_TYPE = {
  [Declarations.SOURCE_DATA_TYPE] = "source",
  [Declarations.ACTION_DATA_TYPE] = "action",
}

--- The declarations of one data_type as registry definitions, in registration order.
---
--- Registration order decides score ties and which declaration keeps a contested
--- prefix or action slot, so it is fixed by each prototype's `order` and then its
--- name rather than by iteration over the prototype table.
---@param mod_data table  name -> mod-data prototype: `prototypes.mod_data` at runtime
---@param data_type string  Declarations.SOURCE_DATA_TYPE or Declarations.ACTION_DATA_TYPE
---@return table  array of definitions: a copy of each prototype's data with `id` set to its name
function Declarations.collect(mod_data, data_type)
  local entries = {}
  for name, prototype in pairs(mod_data) do
    if prototype.data_type == data_type then
      table.insert(entries, { name = name, order = prototype.order or "", data = prototype.data })
    end
  end

  table.sort(entries, function(a, b)
    if a.order ~= b.order then
      return a.order < b.order
    end
    return a.name < b.name
  end)

  local definitions = {}
  for _, entry in ipairs(entries) do
    local definition = {}
    for key, value in pairs(entry.data) do
      definition[key] = value
    end
    definition.id = entry.name
    table.insert(definitions, definition)
  end
  return definitions
end

local function is_non_empty_string(value)
  return type(value) == "string" and value ~= ""
end

local function is_localised_string(value)
  return type(value) == "string" or type(value) == "table"
end

local function is_array_of_non_empty_strings(value)
  if type(value) ~= "table" then
    return false
  end
  local count = 0
  for _ in pairs(value) do
    count = count + 1
  end
  for index = 1, count do
    if not is_non_empty_string(value[index]) then
      return false
    end
  end
  return true
end

local function source_problem(data)
  if not is_non_empty_string(data.type) then
    return "type must be a non-empty string"
  end
  if not is_localised_string(data.label) then
    return "label must be a LocalisedString"
  end
  if not is_non_empty_string(data.interface) then
    return "interface must be a non-empty string"
  end
  if data.prefixes ~= nil and not is_array_of_non_empty_strings(data.prefixes) then
    return "prefixes must be an array of non-empty strings"
  end
  if data.in_default_search ~= nil and type(data.in_default_search) ~= "boolean" then
    return "in_default_search must be a boolean"
  end
  if (data.prefixes == nil or #data.prefixes == 0) and not data.in_default_search then
    return "unreachable: it has no prefixes and is not in the default search"
  end
  return nil
end

local function action_problem(data, custom_inputs)
  if not is_array_of_non_empty_strings(data.types) or #data.types == 0 then
    return "types must be a non-empty array of non-empty strings"
  end
  if not is_localised_string(data.label) then
    return "label must be a LocalisedString"
  end
  if not is_localised_string(data.hint) then
    return "hint must be a LocalisedString"
  end
  if not is_non_empty_string(data.input_name) then
    return "input_name must be a non-empty string"
  end
  if custom_inputs[data.input_name] == nil then
    return ("input_name '%s' names no custom-input prototype"):format(data.input_name)
  end
  if not is_non_empty_string(data.interface) then
    return "interface must be a non-empty string"
  end
  return nil
end

--- Raises on the first malformed source or action declaration.
---
--- Only mistakes in a single declaration are fatal. A declaration written for another
--- contract version is skipped, as are conflicts between declarations (a duplicate
--- type, a contested prefix): those depend on which mods happen to be installed
--- together, so Registry logs and skips them instead of refusing to start the game.
--- Runs from data-final-fixes.lua, so a change a dependent mod makes in its own
--- data-final-fixes is not seen here.
---@param raw table  the data stage's data.raw
function Declarations.validate(raw)
  local mod_data = raw["mod-data"] or {}
  local custom_inputs = raw["custom-input"] or {}

  local names = {}
  for name in pairs(mod_data) do
    table.insert(names, name)
  end
  table.sort(names)

  for _, name in ipairs(names) do
    local prototype = mod_data[name]
    local kind = KIND_BY_DATA_TYPE[prototype.data_type]
    local data = prototype.data
    if kind ~= nil and type(data) == "table" and data.contract_version == Declarations.CONTRACT_VERSION then
      local problem
      if kind == "source" then
        problem = source_problem(data)
      else
        problem = action_problem(data, custom_inputs)
      end
      if problem ~= nil then
        error(("quidquid: %s '%s': %s"):format(kind, name, problem), 0)
      end
    end
  end
end

return Declarations
