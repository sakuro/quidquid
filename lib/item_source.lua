local substring_match = require("lib.substring_match")
local TranslationCache = require("lib.translation_cache")

local ItemSource = {}

function ItemSource.build_candidates(query, items, locale, translation_cache, include_hidden)
  local candidates = {}
  for _, item in ipairs(items) do
    if include_hidden or not item.hidden then
      local matched = substring_match(query, item.name)
      if not matched then
        local translated = translation_cache:get(locale, item.name)
        matched = type(translated) == "string" and substring_match(query, translated)
      end
      if matched then
        table.insert(candidates, {
          type = "item", id = item.name, label = item.localised_name, icon = "item/" .. item.name,
        })
      end
    end
  end
  return candidates
end

local pending = {}
local in_flight = {}

local function collect_items()
  local items = {}
  for _, item in pairs(prototypes.item) do
    table.insert(items, item)
  end
  return items
end

local function missing_items(items, locale)
  local missing = {}
  for _, item in ipairs(items) do
    if TranslationCache:get(locale, item.name) == nil then
      table.insert(missing, item)
    end
  end
  return missing
end

local function request_missing_translations(player, locale)
  local missing = missing_items(collect_items(), locale)
  for _, item in ipairs(missing) do
    local id = player:request_translation(item.localised_name)
    in_flight[id] = { locale = locale, item_name = item.name }
  end
end

local function notify_and_clear_pending(locale)
  local waiting = pending[locale]
  if waiting ~= nil then
    for player_index in pairs(waiting) do
      local player = game.get_player(player_index)
      if player ~= nil then
        player:print({"quidquid.item-source-translations-ready"})
      end
    end
  end
  pending[locale] = nil
end

local function check_locale_completion(locale)
  if #missing_items(collect_items(), locale) > 0 then
    return
  end
  TranslationCache:mark_complete(locale)
  notify_and_clear_pending(locale)
end

local function remove_from_other_pending(player_index, current_locale)
  for locale, waiting in pairs(pending) do
    if locale ~= current_locale and waiting[player_index] then
      waiting[player_index] = nil
      if next(waiting) == nil then
        pending[locale] = nil
      end
    end
  end
end

local function ensure_locale_progress(player)
  local locale = player.locale
  remove_from_other_pending(player.index, locale)
  if TranslationCache:is_complete(locale) then
    return
  end
  local already_pending = pending[locale] ~= nil and next(pending[locale]) ~= nil
  pending[locale] = pending[locale] or {}
  pending[locale][player.index] = true
  if not already_pending then
    request_missing_translations(player, locale)
  end
end

function ItemSource.on_string_translated(event)
  local entry = in_flight[event.id]
  if entry == nil then
    return
  end
  in_flight[event.id] = nil
  if event.translated then
    TranslationCache:set(entry.locale, entry.item_name, event.result)
  else
    TranslationCache:set(entry.locale, entry.item_name, false)
  end
  check_locale_completion(entry.locale)
end

function ItemSource.on_player_joined_game(event)
  local player = game.get_player(event.player_index)
  if player ~= nil then
    ensure_locale_progress(player)
  end
end

-- on_player_locale_changed only tells us who changed locale, not the new value (read via
-- player.locale, already current by the time the event fires) — otherwise identical to
-- on_player_joined_game, so they share one handler.
ItemSource.on_player_locale_changed = ItemSource.on_player_joined_game

function ItemSource.on_player_left_game(event)
  local player_index = event.player_index
  for locale, waiting in pairs(pending) do
    if waiting[player_index] then
      waiting[player_index] = nil
      local successor_index = next(waiting)
      if successor_index == nil then
        pending[locale] = nil
      else
        local successor = game.get_player(successor_index)
        if successor ~= nil then
          request_missing_translations(successor, locale)
        end
      end
    end
  end
end

function ItemSource.on_init()
  for _, player in pairs(game.players) do
    ensure_locale_progress(player)
  end
end

function ItemSource.on_configuration_changed()
  TranslationCache:clear()
  in_flight = {}
  pending = {}
  for _, player in pairs(game.players) do
    ensure_locale_progress(player)
  end
end

return ItemSource
