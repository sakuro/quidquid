local TranslationCache = {}

local function ensure_stores()
  storage.translation_cache = storage.translation_cache or {}
  storage.translated_locales = storage.translated_locales or {}
end

function TranslationCache:get(locale, internal_name)
  ensure_stores()
  local locale_cache = storage.translation_cache[locale]
  if locale_cache == nil then
    return nil
  end
  return locale_cache[internal_name]
end

function TranslationCache:set(locale, internal_name, translated)
  ensure_stores()
  storage.translation_cache[locale] = storage.translation_cache[locale] or {}
  storage.translation_cache[locale][internal_name] = translated
end

function TranslationCache:is_complete(locale)
  ensure_stores()
  return storage.translated_locales[locale] == true
end

function TranslationCache:mark_complete(locale)
  ensure_stores()
  storage.translated_locales[locale] = true
end

function TranslationCache:clear()
  storage.translation_cache = {}
  storage.translated_locales = {}
end

return TranslationCache
