local DefaultSearch = require("lib.default_search")
local Declarations = require("lib.declarations")

local Registry = {}
Registry.__index = Registry

local function noop_logger(_) end

--- A registry of the sources and actions declared as mod-data prototypes.
---@param logger function|nil  called with one message per rejection; defaults to a no-op
---@param settings table|nil  `{ classify, enabled }`, as DefaultSearch.runtime; defaults to it
---@return Registry
function Registry.new(logger, settings)
  return setmetatable({
    sources = {},
    actions = {},
    prefix_owners = {},
    type_owners = {},
    action_slots = {},
    logger = logger or noop_logger,
    settings = settings or DefaultSearch.runtime,
  }, Registry)
end

--- Registers a source, or rejects it and says why in the log.
---
--- Rejection is a return value and a log line, never an error: what is rejected here
--- is a declaration for another contract version or one conflicting with another
--- mod's, and raising would refuse to load any save with that pair of mods installed.
--- A malformed declaration has already failed at startup (Declarations.validate).
--- Reachability and the default-search setting are checked here rather than at
--- startup, because a setting cannot be read in the data stage: a source is
--- rejected when its default-search setting exists under the wrong type or
--- setting_type, and when it has neither that setting nor any prefixes. A prefix
--- already taken is skipped while the rest of the registration succeeds -- the
--- source is still reachable, just not under that prefix. See EXTENDING.md
--- "Rejections and failures".
---@param definition table  see EXTENDING.md "Sources"; from Declarations.collect
---@return boolean  false when the definition was rejected outright
function Registry:register_source(definition)
  if definition.contract_version ~= Declarations.CONTRACT_VERSION then
    self.logger(
      ("quidquid: source '%s' rejected: unsupported contract_version %s (expected %d)"):format(
        tostring(definition.id),
        tostring(definition.contract_version),
        Declarations.CONTRACT_VERSION
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

  if DefaultSearch.ALWAYS[definition.id] then
    definition.default_search_fixed = true
  else
    local setting_name = DefaultSearch.setting_name(definition.id)
    local classification = self.settings.classify(setting_name)
    if classification == "invalid" then
      self.logger(
        ("quidquid: source '%s' rejected: setting '%s' must be a runtime-per-user bool-setting"):format(
          tostring(definition.id),
          setting_name
        )
      )
      return false
    elseif classification == nil then
      if definition.prefixes == nil or #definition.prefixes == 0 then
        self.logger(
          ("quidquid: source '%s' rejected: unreachable: it has no prefixes and no '%s' setting"):format(
            tostring(definition.id),
            setting_name
          )
        )
        return false
      end
    else
      definition.default_search_setting = setting_name
    end
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

--- The sources taking part in an unlocked search for one player, in registration order.
---
--- Quidquid's own sources (DefaultSearch.ALWAYS) are always included; an extension's
--- source joins only when the player's own default-search setting is on. A source with
--- neither -- prefix-only -- never appears here.
---@param player_index uint
---@return table  the source definitions in the default search for that player
function Registry:default_search_sources(player_index)
  local selected = {}
  for _, source in ipairs(self.sources) do
    if source.default_search_fixed then
      table.insert(selected, source)
    elseif
      source.default_search_setting ~= nil and self.settings.enabled(player_index, source.default_search_setting)
    then
      table.insert(selected, source)
    end
  end
  return selected
end

--- The source a prefix word locks the palette to.
---
--- Looked up exactly, so prefixes are case-sensitive even though the search itself
--- is not: "R" and "r" are separate prefixes and two sources may hold one each. That
--- asymmetry is deliberate -- it frees the uppercase letters for sources whose
--- natural initial is already taken. See EXTENDING.md "Definition".
---@param prefix string
---@return table|nil  nil when no source claimed that prefix
function Registry:source_for_prefix(prefix)
  return self.prefix_owners[prefix]
end

--- The source registered under a given id.
---@param id string|nil
---@return table|nil  nil when no source has that id, or id is nil
function Registry:source_by_id(id)
  if id == nil then
    return nil
  end
  for _, source in ipairs(self.sources) do
    if source.id == id then
      return source
    end
  end
  return nil
end

--- Registers an action, or rejects it and says why in the log.
---
--- Same contract as register_source: a rejection is a return value and a log line.
--- A type/input_name pair already taken is skipped while the rest of the
--- registration succeeds, so the action still applies to its other types.
---@param definition table  see EXTENDING.md "Actions"; from Declarations.collect
---@return boolean  false when the definition was rejected outright
function Registry:register_action(definition)
  if definition.contract_version ~= Declarations.CONTRACT_VERSION then
    self.logger(
      ("quidquid: action '%s' rejected: unsupported contract_version %s (expected %d)"):format(
        tostring(definition.id),
        tostring(definition.contract_version),
        Declarations.CONTRACT_VERSION
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

--- The actions offered for one candidate right now, keyed by input_name.
---
--- An is_available that raises counts as unavailable and is logged, rather than
--- taking the whole palette down with it (EXTENDING.md "Rejections and failures").
---@param selected_candidate table  only its `type` is read
---@param player_index uint
---@param caller RemoteCaller
---@return table  input_name -> action definition; empty when nothing applies
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
