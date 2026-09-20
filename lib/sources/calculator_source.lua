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

-- Rounds to DECIMAL_PLACES, then trims trailing zeros and a bare trailing "."
-- so an integer result reads "3", not "3.0000".
function CalculatorSource.format_result(value)
  local formatted = ("%." .. DECIMAL_PLACES .. "f"):format(value)
  formatted = formatted:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
  return formatted
end

-- Takes a pcall(helpers.evaluate_expression, query, SUFFIX_VARIABLES) result pair.
-- Returns the numeric value on success, or nil for a parse/eval error, a non-number
-- result, or a non-finite one (NaN, +-inf -- e.g. "1/0") -- there is no meaningful
-- "result" to show for any of these, so they're all folded into the same "no
-- candidate" outcome from the caller's perspective.
function CalculatorSource.classify(ok, result)
  if not ok or type(result) ~= "number" then
    return nil
  end
  if result ~= result or result == math.huge or result == -math.huge then
    return nil
  end
  return result
end

local function search(query, _player_index)
  if query == "" then
    return {}
  end
  local value = CalculatorSource.classify(pcall(helpers.evaluate_expression, query, SUFFIX_VARIABLES))
  if value == nil then
    return {}
  end
  return {
    {
      type = "calculation",
      id = "result",
      label = CalculatorSource.format_result(value),
      icon = "item/display-panel",
      search_score = 1, -- required by PaletteLogic.merge_candidates; arbitrary, only one candidate ever exists
      numeric = true, -- tells the palette this candidate's label is a value, not a name, so it renders right-aligned
    },
  }
end

-- Reuses the same "did this evaluate to a usable number" check search()
-- itself uses, so the calculator's invalid-input signal (an empty search
-- result) and its palette-invalid-style signal never disagree.
local function is_query_valid(query, _player_index)
  if query == "" then
    return true
  end
  return CalculatorSource.classify(pcall(helpers.evaluate_expression, query, SUFFIX_VARIABLES)) ~= nil
end

function CalculatorSource.register()
  remote.add_interface("quidquid.calculator-source", { search = search, is_query_valid = is_query_valid })
  remote.call("quidquid", "register_source", {
    version = 1,
    id = "calculator",
    type = "calculation",
    label = SOURCE_LABEL,
    prefixes = { "=" },
    default_active = false, -- excluded from the unlocked default search
    interface = "quidquid.calculator-source",
  })
end

return CalculatorSource
