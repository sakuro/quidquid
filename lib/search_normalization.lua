local generated_mapping = require("lib.search_mapping")

local RULE_VERSION = "unicode-18.0.0-r2"

-- These are the small set of compatibility mappings that are useful for
-- names, but are not canonical decompositions in the UCD.
local explicit_mapping = {
  [0x00E6] = { 0x0061, 0x0065 }, -- æ
  [0x00C6] = { 0x0061, 0x0065 }, -- Æ
  [0x00F8] = { 0x006F }, -- ø
  [0x00D8] = { 0x006F }, -- Ø
  [0x0111] = { 0x0064 }, -- đ
  [0x0110] = { 0x0064 }, -- Đ
  [0x0127] = { 0x0068 }, -- ħ
  [0x0131] = { 0x0131 }, -- dotless i is not plain i
  [0x0142] = { 0x006C }, -- ł
  [0x0141] = { 0x006C }, -- Ł
  [0x0153] = { 0x006F, 0x0065 }, -- œ
  [0x0152] = { 0x006F, 0x0065 }, -- Œ
  [0x0167] = { 0x0074 }, -- ŧ
}

local kana_compose = {
  [0x30AB] = { [0x3099] = 0x30AC },
  [0x30AD] = { [0x3099] = 0x30AE },
  [0x30AF] = { [0x3099] = 0x30B0 },
  [0x30B1] = { [0x3099] = 0x30B2 },
  [0x30B3] = { [0x3099] = 0x30B4 },
  [0x30B5] = { [0x3099] = 0x30B6 },
  [0x30B7] = { [0x3099] = 0x30B8 },
  [0x30B9] = { [0x3099] = 0x30BA },
  [0x30BB] = { [0x3099] = 0x30BC },
  [0x30BD] = { [0x3099] = 0x30BE },
  [0x30BF] = { [0x3099] = 0x30C0 },
  [0x30C1] = { [0x3099] = 0x30C2 },
  [0x30C4] = { [0x3099] = 0x30C5 },
  [0x30C6] = { [0x3099] = 0x30C7 },
  [0x30C8] = { [0x3099] = 0x30C9 },
  [0x30CF] = { [0x3099] = 0x30D0, [0x309A] = 0x30D1 },
  [0x30D2] = { [0x3099] = 0x30D3, [0x309A] = 0x30D4 },
  [0x30D5] = { [0x3099] = 0x30D6, [0x309A] = 0x30D7 },
  [0x30D8] = { [0x3099] = 0x30D9, [0x309A] = 0x30DA },
  [0x30DB] = { [0x3099] = 0x30DC, [0x309A] = 0x30DD },
  [0x30A6] = { [0x3099] = 0x30F4 },
  [0x30EF] = { [0x3099] = 0x30F7 },
  [0x30F0] = { [0x3099] = 0x30F8 },
  [0x30F1] = { [0x3099] = 0x30F9 },
  [0x30F2] = { [0x3099] = 0x30FA },
}

local halfwidth_kana = {
  [0xFF66] = 0x30F2,
  [0xFF67] = 0x30A1,
  [0xFF68] = 0x30A3,
  [0xFF69] = 0x30A5,
  [0xFF6A] = 0x30A7,
  [0xFF6B] = 0x30A9,
  [0xFF6C] = 0x30E3,
  [0xFF6D] = 0x30E5,
  [0xFF6E] = 0x30E7,
  [0xFF6F] = 0x30C3,
  [0xFF70] = 0x30FC,
  [0xFF71] = 0x30A2,
  [0xFF72] = 0x30A4,
  [0xFF73] = 0x30A6,
  [0xFF74] = 0x30A8,
  [0xFF75] = 0x30AA,
  [0xFF76] = 0x30AB,
  [0xFF77] = 0x30AD,
  [0xFF78] = 0x30AF,
  [0xFF79] = 0x30B1,
  [0xFF7A] = 0x30B3,
  [0xFF7B] = 0x30B5,
  [0xFF7C] = 0x30B7,
  [0xFF7D] = 0x30B9,
  [0xFF7E] = 0x30BB,
  [0xFF7F] = 0x30BD,
  [0xFF80] = 0x30BF,
  [0xFF81] = 0x30C1,
  [0xFF82] = 0x30C4,
  [0xFF83] = 0x30C6,
  [0xFF84] = 0x30C8,
  [0xFF85] = 0x30DB,
  [0xFF86] = 0x30DE,
  [0xFF87] = 0x30DF,
  [0xFF88] = 0x30E0,
  [0xFF89] = 0x30E1,
  [0xFF8A] = 0x30E2,
  [0xFF8B] = 0x30E4,
  [0xFF8C] = 0x30E6,
  [0xFF8D] = 0x30E8,
  [0xFF8E] = 0x30E9,
  [0xFF8F] = 0x30EA,
  [0xFF90] = 0x30EB,
  [0xFF91] = 0x30EC,
  [0xFF92] = 0x30ED,
  [0xFF93] = 0x30EF,
  [0xFF94] = 0x30F3,
  [0xFF9E] = 0x3099,
  [0xFF9F] = 0x309A,
}

-- Hangul is decomposed to compatibility jamo (U+3131..U+3163) rather than to
-- conjoining jamo, because compatibility jamo is what the keyboard already
-- produces for a lone keystroke. Folding onto it means a consonant matches
-- wherever it sits, initial or final -- which is what a half-typed syllable and
-- an initials-only (choseong) query both need. Without this, a syllable in
-- progress and the finished one are unrelated code points (처 U+CC98, 철 U+CCA0)
-- and incremental search only lands on completed syllables.
local HANGUL_FIRST = 0xAC00
local HANGUL_LAST = 0xD7A3
local JUNGSEONG_FIRST = 0x314F
local JUNGSEONG_COUNT = 21
local JONGSEONG_COUNT = 28

local choseong_compat = {
  [0] = 0x3131, -- ㄱ
  0x3132, -- ㄲ
  0x3134, -- ㄴ
  0x3137, -- ㄷ
  0x3138, -- ㄸ
  0x3139, -- ㄹ
  0x3141, -- ㅁ
  0x3142, -- ㅂ
  0x3143, -- ㅃ
  0x3145, -- ㅅ
  0x3146, -- ㅆ
  0x3147, -- ㅇ
  0x3148, -- ㅈ
  0x3149, -- ㅉ
  0x314A, -- ㅊ
  0x314B, -- ㅋ
  0x314C, -- ㅌ
  0x314D, -- ㅍ
  0x314E, -- ㅎ
}

local jongseong_compat = {
  0x3131, -- ㄱ
  0x3132, -- ㄲ
  0x3133, -- ㄳ
  0x3134, -- ㄴ
  0x3135, -- ㄵ
  0x3136, -- ㄶ
  0x3137, -- ㄷ
  0x3139, -- ㄹ
  0x313A, -- ㄺ
  0x313B, -- ㄻ
  0x313C, -- ㄼ
  0x313D, -- ㄽ
  0x313E, -- ㄾ
  0x313F, -- ㄿ
  0x3140, -- ㅀ
  0x3141, -- ㅁ
  0x3142, -- ㅂ
  0x3144, -- ㅄ
  0x3145, -- ㅅ
  0x3146, -- ㅆ
  0x3147, -- ㅇ
  0x3148, -- ㅈ
  0x314A, -- ㅊ
  0x314B, -- ㅋ
  0x314C, -- ㅌ
  0x314D, -- ㅍ
  0x314E, -- ㅎ
}

-- Conjoining jamo (what NFD text carries) and halfwidth jamo both fold onto the
-- compatibility letters. The halfwidth vowels sit in four runs with gaps between
-- them, so the runs are listed rather than derived from a single offset.
local jamo_compat = {}
for index = 0, #choseong_compat do
  jamo_compat[0x1100 + index] = choseong_compat[index]
end
for index = 0, JUNGSEONG_COUNT - 1 do
  jamo_compat[0x1161 + index] = JUNGSEONG_FIRST + index
end
for index = 1, JONGSEONG_COUNT - 1 do
  jamo_compat[0x11A7 + index] = jongseong_compat[index]
end
for _, run in ipairs({
  { 0xFFA1, 0xFFBE, 0x3131 },
  { 0xFFC2, 0xFFC7, 0x314F },
  { 0xFFCA, 0xFFCF, 0x3155 },
  { 0xFFD2, 0xFFD7, 0x315B },
  { 0xFFDA, 0xFFDC, 0x3161 },
}) do
  for codepoint = run[1], run[2] do
    jamo_compat[codepoint] = run[3] + codepoint - run[1]
  end
end

-- Clusters and compound vowels split into the keystrokes that produce them, so
-- the syllable in progress prefixes the finished one (고 before 광, 달 before 닭).
-- Doubled consonants are deliberately left whole: they are one shifted keystroke.
local compat_jamo_parts = {
  [0x3133] = { 0x3131, 0x3145 }, -- ㄳ
  [0x3135] = { 0x3134, 0x3148 }, -- ㄵ
  [0x3136] = { 0x3134, 0x314E }, -- ㄶ
  [0x313A] = { 0x3139, 0x3131 }, -- ㄺ
  [0x313B] = { 0x3139, 0x3141 }, -- ㄻ
  [0x313C] = { 0x3139, 0x3142 }, -- ㄼ
  [0x313D] = { 0x3139, 0x3145 }, -- ㄽ
  [0x313E] = { 0x3139, 0x314C }, -- ㄾ
  [0x313F] = { 0x3139, 0x314D }, -- ㄿ
  [0x3140] = { 0x3139, 0x314E }, -- ㅀ
  [0x3144] = { 0x3142, 0x3145 }, -- ㅄ
  [0x3158] = { 0x3157, 0x314F }, -- ㅘ
  [0x3159] = { 0x3157, 0x3150 }, -- ㅙ
  [0x315A] = { 0x3157, 0x3163 }, -- ㅚ
  [0x315D] = { 0x315C, 0x3153 }, -- ㅝ
  [0x315E] = { 0x315C, 0x3154 }, -- ㅞ
  [0x315F] = { 0x315C, 0x3163 }, -- ㅟ
  [0x3162] = { 0x3161, 0x3163 }, -- ㅢ
}

local function utf8_decode(value)
  local codepoints = {}
  local index = 1
  while index <= #value do
    local start = index
    local first = value:byte(index)
    local count, codepoint
    if first < 0x80 then
      count, codepoint = 1, first
    elseif first >= 0xC2 and first <= 0xDF then
      count = 2
      codepoint = first - 0xC0
    elseif first >= 0xE0 and first <= 0xEF then
      count = 3
      codepoint = first - 0xE0
    elseif first >= 0xF0 and first <= 0xF4 then
      count = 4
      codepoint = first - 0xF0
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
    table.insert(codepoints, { value = codepoint, start_byte = start, end_byte = index + count - 1 })
    index = index + count
  end
  return codepoints
end

local function utf8_encode(codepoints)
  local result = {}
  for _, codepoint in ipairs(codepoints) do
    if codepoint < 0x80 then
      table.insert(result, string.char(codepoint))
    elseif codepoint < 0x800 then
      table.insert(result, string.char(0xC0 + math.floor(codepoint / 0x40), 0x80 + codepoint % 0x40))
    elseif codepoint < 0x10000 then
      table.insert(
        result,
        string.char(
          0xE0 + math.floor(codepoint / 0x1000),
          0x80 + math.floor(codepoint / 0x40) % 0x40,
          0x80 + codepoint % 0x40
        )
      )
    else
      table.insert(
        result,
        string.char(
          0xF0 + math.floor(codepoint / 0x40000),
          0x80 + math.floor(codepoint / 0x1000) % 0x40,
          0x80 + math.floor(codepoint / 0x40) % 0x40,
          0x80 + codepoint % 0x40
        )
      )
    end
  end
  return table.concat(result)
end

local function is_removed_mark(codepoint)
  return (codepoint >= 0x0300 and codepoint <= 0x036F)
    or (codepoint >= 0x1AB0 and codepoint <= 0x1AFF)
    or (codepoint >= 0x1DC0 and codepoint <= 0x1DFF)
    or (codepoint >= 0x20D0 and codepoint <= 0x20FF)
    or (codepoint >= 0xFE20 and codepoint <= 0xFE2F)
    or (codepoint >= 0x0591 and codepoint <= 0x05C7)
    or (codepoint >= 0x0610 and codepoint <= 0x061A)
    or (codepoint >= 0x064B and codepoint <= 0x065F)
    or codepoint == 0x0670
    or (codepoint >= 0x06D6 and codepoint <= 0x06ED)
end

local function map_codepoint_once(codepoint, locale)
  if locale == "tr" then
    if codepoint == 0x0049 then
      return { 0x0131 }
    elseif codepoint == 0x0130 then
      return { 0x0069 }
    end
  end
  if codepoint >= 0x3041 and codepoint <= 0x3096 then
    return { codepoint + 0x60 }
  elseif codepoint >= 0x309D and codepoint <= 0x309F then
    return { codepoint + 0x60 }
  elseif codepoint >= 0xFF01 and codepoint <= 0xFF5E then
    return { codepoint - 0xFEE0 }
  elseif codepoint == 0x3000 then
    return { 0x20 }
  end
  if codepoint >= HANGUL_FIRST and codepoint <= HANGUL_LAST then
    local index = codepoint - HANGUL_FIRST
    local trailing = index % JONGSEONG_COUNT
    local syllable = {
      choseong_compat[math.floor(index / (JUNGSEONG_COUNT * JONGSEONG_COUNT))],
      JUNGSEONG_FIRST + math.floor(index % (JUNGSEONG_COUNT * JONGSEONG_COUNT) / JONGSEONG_COUNT),
    }
    if trailing > 0 then
      table.insert(syllable, jongseong_compat[trailing])
    end
    return syllable
  end
  local jamo = jamo_compat[codepoint]
  if jamo ~= nil then
    return { jamo }
  end
  return compat_jamo_parts[codepoint] or explicit_mapping[codepoint] or generated_mapping[codepoint] or { codepoint }
end

-- A single pass is not enough, because a mapping can land on a code point that is
-- itself mapped. Both directions occur: the generated table stores intermediate
-- decompositions (U+01DF -> U+00E4 + U+0304, where U+00E4 still folds to "a"), and
-- the branches above hand back a code point the table then case-folds (fullwidth
-- U+FF29 -> U+0049 -> "i"). Iterating to a fixpoint covers both without the
-- generator having to fully resolve its own output.
--
-- The cap is a guard against a mapping cycle, not a real depth: the longest chains
-- in Unicode 18 settle in two or three passes.
local MAX_MAPPING_PASSES = 8

local function map_codepoint(codepoint, locale)
  local values = map_codepoint_once(codepoint, locale)
  if #values == 1 and values[1] == codepoint then
    return values
  end

  for _ = 2, MAX_MAPPING_PASSES do
    local expanded = {}
    local changed = false
    for _, value in ipairs(values) do
      local mapped = map_codepoint_once(value, locale)
      if #mapped ~= 1 or mapped[1] ~= value then
        changed = true
      end
      for _, result in ipairs(mapped) do
        table.insert(expanded, result)
      end
    end
    values = expanded
    if not changed then
      break
    end
  end
  return values
end

local function normalize(value, field_kind, locale)
  if type(value) ~= "string" then
    return value, {}
  end
  local decoded = utf8_decode(value)
  if decoded == nil then
    return value, nil
  end
  local source = {}
  local index = 1
  while index <= #decoded do
    local item = decoded[index]
    local next_item = decoded[index + 1]
    local mapped = halfwidth_kana[item.value]
    if mapped ~= nil and next_item ~= nil and (next_item.value == 0xFF9E or next_item.value == 0xFF9F) then
      local mark = next_item.value == 0xFF9E and 0x3099 or 0x309A
      local composed = kana_compose[mapped] and kana_compose[mapped][mark]
      if composed ~= nil then
        table.insert(source, { value = composed, start_byte = item.start_byte, end_byte = next_item.end_byte })
        index = index + 2
      else
        table.insert(source, { value = mapped, start_byte = item.start_byte, end_byte = item.end_byte })
        table.insert(source, { value = mark, start_byte = next_item.start_byte, end_byte = next_item.end_byte })
        index = index + 2
      end
    else
      if mapped ~= nil then
        item = { value = mapped, start_byte = item.start_byte, end_byte = item.end_byte }
      end
      table.insert(source, item)
      index = index + 1
    end
  end

  local normalized = {}
  local position_map = {}
  local pending_start_byte
  for _, item in ipairs(source) do
    local values = map_codepoint(item.value, field_kind == "internal" and nil or locale)
    for _, codepoint in ipairs(values) do
      if (codepoint == 0x3099 or codepoint == 0x309A) and #normalized > 0 then
        local composed = kana_compose[normalized[#normalized]] and kana_compose[normalized[#normalized]][codepoint]
        if composed ~= nil then
          normalized[#normalized] = composed
          position_map[#position_map].end_byte = item.end_byte
        elseif not is_removed_mark(codepoint) then
          table.insert(normalized, codepoint)
          table.insert(position_map, {
            start_byte = pending_start_byte or item.start_byte,
            end_byte = item.end_byte,
          })
          pending_start_byte = nil
        end
      elseif codepoint == 0x0640 then
        if #position_map > 0 then
          position_map[#position_map].end_byte = item.end_byte
        else
          pending_start_byte = pending_start_byte or item.start_byte
        end
      elseif is_removed_mark(codepoint) then
        if #position_map > 0 then
          position_map[#position_map].end_byte = item.end_byte
        else
          pending_start_byte = pending_start_byte or item.start_byte
        end
      else
        table.insert(normalized, codepoint)
        table.insert(position_map, {
          start_byte = pending_start_byte or item.start_byte,
          end_byte = item.end_byte,
        })
        pending_start_byte = nil
      end
    end
  end
  return utf8_encode(normalized), position_map
end

return {
  normalize = normalize,
  rule_version = RULE_VERSION,
}
