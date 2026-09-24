local NumberFormat = {}

-- Display tiers for suffixed, ascending.
local DISPLAY_TIERS = {
  { divisor = 1e3, suffix = "k" },
  { divisor = 1e6, suffix = "M" },
  { divisor = 1e9, suffix = "B" },
  { divisor = 1e12, suffix = "T" },
}

--- Compact form of a value: one decimal digit per tier, except that the k tier
--- drops it from 10k up, and values under 1000 are whole numbers.
---
--- Digits beyond the shown precision are truncated toward zero, never rounded, so a
--- value never displays as more than it is (999999 is "999k", not "1.0M"); this also
--- means a value cannot carry into the next tier.
---@param value number
---@return string
function NumberFormat.suffixed(value)
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

return NumberFormat
