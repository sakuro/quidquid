-- lib/remote_caller.lua
local RemoteCaller = {}

function RemoteCaller:has(interface_name, function_name)
  local functions = remote.interfaces[interface_name]
  return functions ~= nil and functions[function_name] == true
end

function RemoteCaller:call(interface_name, function_name, ...)
  return remote.call(interface_name, function_name, ...)
end

return RemoteCaller
