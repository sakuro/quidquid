-- Adapted from swarn/fzy-lua (MIT; see LICENSE-fzy-lua.txt).
-- This version operates on normalized UTF-8 code points instead of bytes and
-- returns positions in the normalized code-point index space.

local SCORE_GAP_LEADING = -0.005
local SCORE_GAP_TRAILING = -0.005
local SCORE_GAP_INNER = -0.01
local SCORE_MATCH_CONSECUTIVE = 1.0
local SCORE_MATCH_SLASH = 0.9
local SCORE_MATCH_WORD = 0.8
local SCORE_MATCH_CAPITAL = 0.7
local SCORE_MATCH_DOT = 0.6
local SCORE_MAX = math.huge
local SCORE_MIN = -math.huge
local MATCH_MAX_LENGTH = 1024

local function decode(value)
  local codepoints = {}
  local index = 1
  while index <= #value do
    local first = value:byte(index)
    local count, codepoint
    if first < 0x80 then
      count, codepoint = 1, first
    elseif first >= 0xC2 and first <= 0xDF then
      count, codepoint = 2, first - 0xC0
    elseif first >= 0xE0 and first <= 0xEF then
      count, codepoint = 3, first - 0xE0
    elseif first >= 0xF0 and first <= 0xF4 then
      count, codepoint = 4, first - 0xF0
    else
      return nil
    end
    for offset = 1, count - 1 do
      local byte = value:byte(index + offset)
      if byte == nil or byte < 0x80 or byte > 0xBF then
        return nil
      end
      codepoint = codepoint * 0x40 + byte - 0x80
    end
    if
      (count == 2 and codepoint < 0x80)
      or (count == 3 and codepoint < 0x800)
      or (count == 4 and codepoint < 0x10000)
      or codepoint > 0x10FFFF
      or (codepoint >= 0xD800 and codepoint <= 0xDFFF)
    then
      return nil
    end
    table.insert(codepoints, codepoint)
    index = index + count
  end
  return codepoints
end

local function is_lower(codepoint)
  return codepoint >= 0x61 and codepoint <= 0x7A
end

local function is_upper(codepoint)
  return codepoint >= 0x41 and codepoint <= 0x5A
end

local function precompute_bonus(haystack)
  local match_bonus = {}
  local last_codepoint = 0x2F
  for index, codepoint in ipairs(haystack) do
    if last_codepoint == 0x2F or last_codepoint == 0x5C then
      match_bonus[index] = SCORE_MATCH_SLASH
    elseif last_codepoint == 0x2D or last_codepoint == 0x5F or last_codepoint == 0x20 then
      match_bonus[index] = SCORE_MATCH_WORD
    elseif last_codepoint == 0x2E then
      match_bonus[index] = SCORE_MATCH_DOT
    elseif is_lower(last_codepoint) and is_upper(codepoint) then
      match_bonus[index] = SCORE_MATCH_CAPITAL
    else
      match_bonus[index] = 0
    end
    last_codepoint = codepoint
  end
  return match_bonus
end

local function has_match(needle, haystack)
  local needle_index = 1
  for _, codepoint in ipairs(haystack) do
    if codepoint == needle[needle_index] then
      needle_index = needle_index + 1
      if needle_index > #needle then
        return true
      end
    end
  end
  return false
end

local function compute(needle, haystack)
  local match_bonus = precompute_bonus(haystack)
  local scores = {}
  local best = {}
  local haystack_length = #haystack
  local needle_length = #needle

  for needle_index = 1, needle_length do
    scores[needle_index] = {}
    best[needle_index] = {}
    local previous_score = SCORE_MIN
    local gap_score = needle_index == needle_length and SCORE_GAP_TRAILING or SCORE_GAP_INNER

    for haystack_index = 1, haystack_length do
      if needle[needle_index] == haystack[haystack_index] then
        local score = SCORE_MIN
        if needle_index == 1 then
          score = (haystack_index - 1) * SCORE_GAP_LEADING + match_bonus[haystack_index]
        elseif haystack_index > 1 then
          local gap = best[needle_index - 1][haystack_index - 1] + match_bonus[haystack_index]
          local consecutive = scores[needle_index - 1][haystack_index - 1] + SCORE_MATCH_CONSECUTIVE
          score = math.max(gap, consecutive)
        end
        scores[needle_index][haystack_index] = score
        previous_score = math.max(score, previous_score + gap_score)
        best[needle_index][haystack_index] = previous_score
      else
        scores[needle_index][haystack_index] = SCORE_MIN
        previous_score = previous_score + gap_score
        best[needle_index][haystack_index] = previous_score
      end
    end
  end
  return scores, best
end

local function fuzzy_match(normalized_query, normalized_target)
  if
    type(normalized_query) ~= "string"
    or type(normalized_target) ~= "string"
    or normalized_query == ""
    or normalized_target == ""
  then
    return nil
  end

  local needle = decode(normalized_query)
  local haystack = decode(normalized_target)
  if needle == nil or haystack == nil then
    return nil
  end
  local needle_length = #needle
  local haystack_length = #haystack
  if needle_length == 0 or haystack_length == 0 or needle_length > haystack_length then
    return nil
  end
  if needle_length > MATCH_MAX_LENGTH or haystack_length > MATCH_MAX_LENGTH then
    return nil
  end
  if not has_match(needle, haystack) then
    return nil
  end
  if needle_length == haystack_length then
    local positions = {}
    for index = 1, needle_length do
      positions[index] = index
    end
    return SCORE_MAX, positions
  end

  local scores, best = compute(needle, haystack)
  local score = best[needle_length][haystack_length]
  if score == SCORE_MIN then
    return nil
  end

  local positions = {}
  local match_required = false
  local haystack_index = haystack_length
  for needle_index = needle_length, 1, -1 do
    while haystack_index >= 1 do
      local direct_score = scores[needle_index][haystack_index]
      if direct_score ~= SCORE_MIN and (match_required or direct_score == best[needle_index][haystack_index]) then
        match_required = needle_index ~= 1
          and haystack_index ~= 1
          and best[needle_index][haystack_index]
            == scores[needle_index - 1][haystack_index - 1] + SCORE_MATCH_CONSECUTIVE
        positions[needle_index] = haystack_index
        haystack_index = haystack_index - 1
        break
      end
      haystack_index = haystack_index - 1
    end
  end
  return score, positions
end

return fuzzy_match
