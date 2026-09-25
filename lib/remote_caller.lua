-- luacheck: no self
--
-- RemoteCaller is a stateless namespace module: its methods use `:` syntax only
-- to match RemoteCaller:has/:call call sites, not because they read or write
-- instance state via `self`.

local RemoteCaller = {}

--- True when that interface exists and declares that function.
---
--- Every interface function in the source and action contracts except `search`
--- and `execute` is optional, so each call site asks this first rather than
--- letting a missing optional raise.
---@param interface_name string
---@param function_name string
---@return boolean
function RemoteCaller:has(interface_name, function_name)
  local functions = remote.interfaces[interface_name]
  return functions ~= nil and functions[function_name] == true
end

--- Calls a remote interface function, passing the arguments through.
---
--- A one-line wrapper so that call sites take the caller as a parameter and a
--- spec can hand them a stub in place of `remote` (see spec/lib/registry_spec.lua).
--- Errors are not caught here: the callers that must tolerate a broken source or
--- action pcall this themselves, because what an error means differs per function
--- (see EXTENDING.md "Rejections and failures").
---@param interface_name string
---@param function_name string
---@param ... any
---@return any
function RemoteCaller:call(interface_name, function_name, ...)
  return remote.call(interface_name, function_name, ...)
end

return RemoteCaller
