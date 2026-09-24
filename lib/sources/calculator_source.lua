local NumberFormat = require("lib.number_format")

local CalculatorSource = {}

local SOURCE_LABEL = { "quidquid.source-calculator" }
local DECIMAL_PLACES = 4

-- helpers.evaluate_expression has no built-in suffix notation, but a number directly
-- followed by an identifier is parsed as implicit multiplication (confirmed
-- empirically: "2k" -> 2*k), so passing these as the `variables` argument gets
-- suffixes for free: "1.5M" evaluates as 1.5 * 1000000. Only k/K (thousand) and
-- m/M (million) are accepted, case-insensitively either way, matching how the base
-- game's own circuit network signal count entry treats them.
local SUFFIX_VARIABLES = { k = 1e3, K = 1e3, m = 1e6, M = 1e6 }

--- The result as the player should read it: rounded to DECIMAL_PLACES, with trailing
--- zeros and a bare trailing "." trimmed so an integer reads "3", not "3.0000".
---@param value number
---@return string
function CalculatorSource.format_result(value)
  local formatted = ("%." .. DECIMAL_PLACES .. "f"):format(value)
  formatted = formatted:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
  return formatted
end

--- The usable number out of an expression evaluation, or nil when there isn't one.
---
--- A parse/eval error, a non-number result, and a non-finite one (NaN, +-inf -- e.g.
--- "1/0") all fold into nil: none of them has a meaningful result to show, so the
--- caller treats them identically.
---@param ok boolean  the pcall status
---@param result any  the pcall value
---@return number|nil
function CalculatorSource.valid_value(ok, result)
  if not ok or type(result) ~= "number" then
    return nil
  end
  if result ~= result or result == math.huge or result == -math.huge then
    return nil
  end
  return result
end

--- The single candidate for an evaluated expression.
---@param value number
---@return table  a candidate; see EXTENDING.md "Candidates"
function CalculatorSource.build_candidate(value)
  return {
    type = "calculation",
    id = "result",
    label = CalculatorSource.format_result(value),
    secondary_text = NumberFormat.suffixed(value),
    icon = "quidquid-calculator",
    search_score = 1, -- required by PaletteLogic.merge_candidates; arbitrary, only one candidate ever exists
    numeric = true, -- tells the palette this candidate's label is a value, not a name, so it renders right-aligned
  }
end

local function search(query, _player_index)
  if query == "" then
    return {}
  end
  local value = CalculatorSource.valid_value(pcall(helpers.evaluate_expression, query, SUFFIX_VARIABLES))
  if value == nil then
    return {}
  end
  return { CalculatorSource.build_candidate(value) }
end

-- Reuses the same "did this evaluate to a usable number" check search()
-- itself uses, so the calculator's invalid-input signal (an empty search
-- result) and its palette-invalid-style signal never disagree.
local function is_query_valid(query, _player_index)
  if query == "" then
    return true
  end
  return CalculatorSource.valid_value(pcall(helpers.evaluate_expression, query, SUFFIX_VARIABLES)) ~= nil
end

--- Adds this source's remote interface and registers it with Quidquid.
---
--- Registered with the "=" prefix and out of the default search: every query would
--- otherwise be handed to the expression evaluator.
function CalculatorSource.register()
  remote.add_interface("quidquid.calculator-source", { search = search, is_query_valid = is_query_valid })
  remote.call("quidquid", "register_source", {
    contract_version = 1,
    id = "calculator",
    type = "calculation",
    label = SOURCE_LABEL,
    prefixes = { "=" },
    in_default_search = false, -- excluded from the unlocked default search
    interface = "quidquid.calculator-source",
  })
end

return CalculatorSource
