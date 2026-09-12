local TranslationCache = require("lib.translation_cache")

local TranslatedPrototypeSource = {}
TranslatedPrototypeSource.__index = TranslatedPrototypeSource

function TranslatedPrototypeSource.new(namespace, collect, source_label)
  return setmetatable({
    namespace = namespace,
    collect = collect,
    source_label = source_label,
    pending = {},
    in_flight = {},
  }, TranslatedPrototypeSource)
end

function TranslatedPrototypeSource:get(locale, internal_name)
  return TranslationCache:get(self.namespace, locale, internal_name)
end

function TranslatedPrototypeSource:missing(locale)
  local missing = {}
  for _, prototype in ipairs(self.collect()) do
    if TranslationCache:get(self.namespace, locale, prototype.name) == nil then
      table.insert(missing, prototype)
    end
  end
  return missing
end

function TranslatedPrototypeSource:request_missing_translations(player, locale)
  local missing = self:missing(locale)
  for _, prototype in ipairs(missing) do
    local id = player.request_translation(prototype.localised_name)
    self.in_flight[id] = { locale = locale, name = prototype.name }
  end
end

function TranslatedPrototypeSource:notify_and_clear_pending(locale)
  local waiting = self.pending[locale]
  if waiting ~= nil then
    for player_index in pairs(waiting) do
      local player = game.get_player(player_index)
      if player ~= nil then
        player.print({"quidquid.source-translations-ready", self.source_label})
      end
    end
  end
  self.pending[locale] = nil
end

function TranslatedPrototypeSource:check_locale_completion(locale)
  if #self:missing(locale) > 0 then
    return
  end
  TranslationCache:mark_complete(self.namespace, locale)
  self:notify_and_clear_pending(locale)
end

function TranslatedPrototypeSource:remove_from_other_pending(player_index, current_locale)
  for locale, waiting in pairs(self.pending) do
    if locale ~= current_locale and waiting[player_index] then
      waiting[player_index] = nil
      if next(waiting) == nil then
        self.pending[locale] = nil
      end
    end
  end
end

function TranslatedPrototypeSource:ensure_locale_progress(player)
  local locale = player.locale
  self:remove_from_other_pending(player.index, locale)
  if TranslationCache:is_complete(self.namespace, locale) then
    return
  end
  local already_pending = self.pending[locale] ~= nil and next(self.pending[locale]) ~= nil
  self.pending[locale] = self.pending[locale] or {}
  self.pending[locale][player.index] = true
  if not already_pending then
    self:request_missing_translations(player, locale)
  end
end

function TranslatedPrototypeSource:on_string_translated(event)
  local entry = self.in_flight[event.id]
  if entry == nil then
    return
  end
  self.in_flight[event.id] = nil
  if event.translated then
    TranslationCache:set(self.namespace, entry.locale, entry.name, event.result)
  else
    TranslationCache:set(self.namespace, entry.locale, entry.name, false)
  end
  self:check_locale_completion(entry.locale)
end

function TranslatedPrototypeSource:on_player_joined_game(event)
  local player = game.get_player(event.player_index)
  if player ~= nil then
    self:ensure_locale_progress(player)
  end
end

-- on_player_locale_changed only tells us who changed locale, not the new value (read via
-- player.locale, already current by the time the event fires) — otherwise identical to
-- on_player_joined_game, so they share one handler.
TranslatedPrototypeSource.on_player_locale_changed = TranslatedPrototypeSource.on_player_joined_game

function TranslatedPrototypeSource:on_player_left_game(event)
  local player_index = event.player_index
  for locale, waiting in pairs(self.pending) do
    if waiting[player_index] then
      waiting[player_index] = nil
      local successor_index = next(waiting)
      if successor_index == nil then
        self.pending[locale] = nil
      else
        local successor = game.get_player(successor_index)
        if successor ~= nil then
          self:request_missing_translations(successor, locale)
        end
      end
    end
  end
end

function TranslatedPrototypeSource:on_init()
  for _, player in pairs(game.players) do
    self:ensure_locale_progress(player)
  end
end

function TranslatedPrototypeSource:on_configuration_changed()
  TranslationCache:clear()
  self.in_flight = {}
  self.pending = {}
  for _, player in pairs(game.players) do
    self:ensure_locale_progress(player)
  end
end

return TranslatedPrototypeSource
