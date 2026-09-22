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
    type_owners = {},
    action_slots = {},
    logger = logger or noop_logger,
  }, Registry)
end

function Registry:register_source(definition)
  if definition.contract_version ~= SOURCE_CONTRACT_VERSION then
    self.logger(
      ("quidquid: source '%s' rejected: unsupported contract_version %s (expected %d)"):format(
        tostring(definition.id),
        tostring(definition.contract_version),
        SOURCE_CONTRACT_VERSION
      )
    )
    return false
  end

  if definition.type == nil then
    self.logger(("quidquid: source '%s' rejected: missing type"):format(tostring(definition.id)))
    return false
  end

  if self.type_owners[definition.type] ~= nil then
    self.logger(
      ("quidquid: source '%s' rejected: type '%s' already registered by '%s'"):format(
        tostring(definition.id),
        definition.type,
        tostring(self.type_owners[definition.type].id)
      )
    )
    return false
  end

  for _, prefix in ipairs(definition.prefixes or {}) do
    if prefix == "" then
      self.logger(
        ("quidquid: source '%s' prefix '' ignored: empty prefixes are not allowed"):format(tostring(definition.id))
      )
    elseif self.prefix_owners[prefix] == nil then
      self.prefix_owners[prefix] = definition
    else
      self.logger(
        ("quidquid: source '%s' prefix '%s' ignored: already registered by '%s'"):format(
          tostring(definition.id),
          prefix,
          tostring(self.prefix_owners[prefix].id)
        )
      )
    end
  end

  self.type_owners[definition.type] = definition
  table.insert(self.sources, definition)
  return true
end

function Registry:default_search_sources()
  local selected = {}
  for _, source in ipairs(self.sources) do
    if source.in_default_search then
      table.insert(selected, source)
    end
  end
  return selected
end

function Registry:source_for_prefix(prefix)
  return self.prefix_owners[prefix]
end

function Registry:register_action(definition)
  if definition.contract_version ~= ACTION_CONTRACT_VERSION then
    self.logger(
      ("quidquid: action '%s' rejected: unsupported contract_version %s (expected %d)"):format(
        tostring(definition.id),
        tostring(definition.contract_version),
        ACTION_CONTRACT_VERSION
      )
    )
    return false
  end

  if definition.input_name == nil or definition.types == nil or #definition.types == 0 then
    self.logger(("quidquid: action '%s' rejected: missing input_name or types"):format(tostring(definition.id)))
    return false
  end

  for _, candidate_type in ipairs(definition.types) do
    self.action_slots[candidate_type] = self.action_slots[candidate_type] or {}
    local slots = self.action_slots[candidate_type]
    if slots[definition.input_name] == nil then
      slots[definition.input_name] = definition
    else
      self.logger(
        ("quidquid: action '%s' input_name '%s' for type '%s' ignored: already registered by '%s'"):format(
          tostring(definition.id),
          definition.input_name,
          candidate_type,
          tostring(slots[definition.input_name].id)
        )
      )
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

  for input_name, definition in pairs(slots) do
    local applicable = true
    -- is_available only gates on state uniform across every candidate of a type
    -- (player/network state, say); a fact specific to one candidate belongs in
    -- execute instead, reported to the player rather than silently hidden.
    if caller:has(definition.interface, "is_available") then
      local ok, result = pcall(caller.call, caller, definition.interface, "is_available", player_index)
      if ok then
        applicable = result
      else
        applicable = false
        self.logger(
          ("quidquid: action '%s' is_available check failed: %s"):format(tostring(definition.id), tostring(result))
        )
      end
    end
    if applicable then
      resolved[input_name] = definition
    end
  end

  return resolved
end

return Registry
