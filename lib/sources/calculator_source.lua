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

-- Display tiers for format_suffixed, ascending. Separate from SUFFIX_VARIABLES, which
-- only covers what the player may type (k/K, m/M) and has no B or T.
local DISPLAY_TIERS = {
  { divisor = 1e3, suffix = "k" },
  { divisor = 1e6, suffix = "M" },
  { divisor = 1e9, suffix = "B" },
  { divisor = 1e12, suffix = "T" },
}

-- Compact form of a value for the secondary line: one decimal digit per tier, except that
-- the k tier drops it from 10k up (the digit adds little there), and values under 1000
-- are whole numbers. Digits beyond the shown precision are truncated toward zero, never
-- rounded, so a value never displays as more than it is (999999 is "999k", not "1.0M");
-- this also means a value cannot carry into the next tier.
function CalculatorSource.format_suffixed(value)
  local magnitude = math.abs(value)
  local tier_index
  for index, tier in ipairs(DISPLAY_TIERS) do
    if magnitude >= tier.divisor then
      tier_index = index
    end
  end
  local sign = value < 0 and "-" or ""
  if tier_index == nil then
    local whole = math.floor(magnitude)
    -- A negative value below one truncates to zero, and "-0" would be misleading.
    return (whole == 0 and "" or sign) .. ("%d"):format(whole)
  end

  local tier = DISPLAY_TIERS[tier_index]
  local text
  if tier_index == 1 and magnitude >= 10 * tier.divisor then
    text = ("%d"):format(math.floor(magnitude / tier.divisor))
  else
    -- Counting in tenths of the tier keeps the truncation on an exact integer division
    -- rather than on a scaled float that can land just below a whole tenth.
    local tenths = math.floor(magnitude / (tier.divisor / 10))
    text = ("%d.%d"):format(math.floor(tenths / 10), tenths % 10)
  end
  return sign .. text .. tier.suffix
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

function CalculatorSource.build_candidate(value)
  return {
    type = "calculation",
    id = "result",
    label = CalculatorSource.format_result(value),
    secondary_text = CalculatorSource.format_suffixed(value),
    icon = "quidquid-calculator",
    search_score = 1, -- required by PaletteLogic.merge_candidates; arbitrary, only one candidate ever exists
    numeric = true, -- tells the palette this candidate's label is a value, not a name, so it renders right-aligned
  }
end

local function search(query, _player_index)
  if query == "" then
    return {}
  end
  local value = CalculatorSource.classify(pcall(helpers.evaluate_expression, query, SUFFIX_VARIABLES))
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
  return CalculatorSource.classify(pcall(helpers.evaluate_expression, query, SUFFIX_VARIABLES)) ~= nil
end

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
