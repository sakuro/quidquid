local SOURCE_CONTRACT_VERSION = 1

local Registry = {}
Registry.__index = Registry

local function noop_logger(_) end

function Registry.new(logger)
  return setmetatable({
    sources = {},
    prefix_owners = {},
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

return Registry
