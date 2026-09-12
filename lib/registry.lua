local SOURCE_CONTRACT_VERSION = 1
local ACTION_CONTRACT_VERSION = 1

local Registry = {}
Registry.__index = Registry

local function noop_logger(_) end

function Registry.new(logger)
  return setmetatable({
    sources = {},
    actions = {},
    prefix_owners = {},
    action_slots = {},
    logger = logger or noop_logger,
  }, Registry)
end

function Registry:register_source(definition)
  if definition.version ~= SOURCE_CONTRACT_VERSION then
    self.logger(("quidquid: source '%s' rejected: unsupported version %s (expected %d)"):format(
      tostring(definition.id), tostring(definition.version), SOURCE_CONTRACT_VERSION))
    return false
  end

  for _, prefix in ipairs(definition.prefixes or {}) do
    if self.prefix_owners[prefix] == nil then
      self.prefix_owners[prefix] = definition
    else
      self.logger(("quidquid: source '%s' prefix '%s' ignored: already registered by '%s'"):format(
        tostring(definition.id), prefix, tostring(self.prefix_owners[prefix].id)))
    end
  end

  table.insert(self.sources, definition)
  return true
end

function Registry:default_active_sources()
  local active = {}
  for _, source in ipairs(self.sources) do
    if source.default_active then
      table.insert(active, source)
    end
  end
  return active
end

function Registry:register_action(definition)
  if definition.version ~= ACTION_CONTRACT_VERSION then
    self.logger(("quidquid: action '%s' rejected: unsupported version %s (expected %d)"):format(
      tostring(definition.id), tostring(definition.version), ACTION_CONTRACT_VERSION))
    return false
  end

  if definition.key == nil or definition.types == nil or #definition.types == 0 then
    self.logger(("quidquid: action '%s' rejected: missing key or types"):format(tostring(definition.id)))
    return false
  end

  for _, candidate_type in ipairs(definition.types) do
    self.action_slots[candidate_type] = self.action_slots[candidate_type] or {}
    local slots = self.action_slots[candidate_type]
    if slots[definition.key] == nil then
      slots[definition.key] = definition
    else
      self.logger(("quidquid: action '%s' key '%s' for type '%s' ignored: already registered by '%s'"):format(
        tostring(definition.id), definition.key, candidate_type, tostring(slots[definition.key].id)))
    end
  end

  table.insert(self.actions, definition)
  return true
end

function Registry:resolve_actions(selected_candidate, player_index, caller)
  local slots = self.action_slots[selected_candidate.type]
  local resolved = {}
  if slots == nil then
    return resolved
  end

  for key, definition in pairs(slots) do
    local applicable = true
    if caller:has(definition.interface, "is_applicable") then
      applicable = caller:call(definition.interface, "is_applicable", selected_candidate, player_index)
    end
    if applicable then
      resolved[key] = definition
    end
  end

  return resolved
end

return Registry
