-- Generate the Unicode search mapping used by lib.search_normalization.
--
-- Usage:
--   lua tools/generate_search_mapping.lua tmp/ucd-18.0.0 lib/search_mapping.lua
--
-- The generated file is deliberately plain Lua so the runtime does not need
-- to parse UCD files.  UnicodeData supplies canonical decompositions and
-- CaseFolding supplies full, locale-independent case folding.

local ucd_dir = assert(arg[1], "missing UCD directory")
local output_path = assert(arg[2], "missing output path")

local function split_semicolon(line)
  local fields = {}
  for field in (line .. ";"):gmatch("(.-);") do
    table.insert(fields, field)
  end
  return fields
end

local function parse_codepoints(value)
  local result = {}
  for hex in value:gmatch("[0-9A-F]+") do
    table.insert(result, tonumber(hex, 16))
  end
  return result
end

local decompositions = {}
local unicode_data = assert(io.open(ucd_dir .. "/UnicodeData.txt", "r"))
for line in unicode_data:lines() do
  if not line:match("^#") and line ~= "" then
    local fields = split_semicolon(line)
    local codepoint = tonumber(fields[1], 16)
    local decomposition = fields[6]
    if decomposition ~= "" and not decomposition:match("^<[^>]+>") then
      decompositions[codepoint] = parse_codepoints(decomposition)
    end
  end
end
unicode_data:close()

local case_folding = {}
local folding_data = assert(io.open(ucd_dir .. "/CaseFolding.txt", "r"))
for line in folding_data:lines() do
  local codepoint, _, mapping = line:match("^%s*([0-9A-F]+)%s*;%s*([CF])%s*;%s*([^;]+)%s*;")
  if codepoint ~= nil then
    case_folding[tonumber(codepoint, 16)] = parse_codepoints(mapping)
  end
end
folding_data:close()

local function copy(values)
  local result = {}
  for _, value in ipairs(values) do
    table.insert(result, value)
  end
  return result
end

local resolving = {}
local function resolve(codepoint)
  if resolving[codepoint] then
    return { codepoint }
  end
  resolving[codepoint] = true
  local result = case_folding[codepoint] and copy(case_folding[codepoint]) or { codepoint }
  local expanded = {}
  for _, value in ipairs(result) do
    local decomposition = decompositions[value]
    if decomposition ~= nil then
      for _, part in ipairs(decomposition) do
        table.insert(expanded, part)
      end
    else
      table.insert(expanded, value)
    end
  end
  resolving[codepoint] = nil
  return expanded
end

local mapping = {}
for codepoint, _ in pairs(case_folding) do
  local values = resolve(codepoint)
  if #values ~= 1 or values[1] ~= codepoint then
    mapping[codepoint] = values
  end
end
for codepoint, _ in pairs(decompositions) do
  local values = resolve(codepoint)
  if #values ~= 1 or values[1] ~= codepoint then
    mapping[codepoint] = values
  end
end

local codepoints = {}
for codepoint, _ in pairs(mapping) do
  table.insert(codepoints, codepoint)
end
table.sort(codepoints)

local output = assert(io.open(output_path, "w"))
output:write("-- Generated from Unicode Character Database 18.0.0. Do not edit.\n")
output:write("return {\n")
for _, codepoint in ipairs(codepoints) do
  output:write(string.format("  [0x%04X] = { ", codepoint))
  for index, value in ipairs(mapping[codepoint]) do
    if index > 1 then
      output:write(", ")
    end
    output:write(string.format("0x%04X", value))
  end
  output:write(" },\n")
end
output:write("}\n")
output:close()
