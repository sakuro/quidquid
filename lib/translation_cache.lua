local TranslationCache = {}

local function ensure_stores()
  storage.translation_cache = storage.translation_cache or {}
  storage.translated_locales = storage.translated_locales or {}
end

function TranslationCache:get(namespace, locale, internal_name)
  ensure_stores()
  local namespace_cache = storage.translation_cache[namespace]
  if namespace_cache == nil then
    return nil
  end
  local locale_cache = namespace_cache[locale]
  if locale_cache == nil then
    return nil
  end
  return locale_cache[internal_name]
end

function TranslationCache:set(namespace, locale, internal_name, translated)
  ensure_stores()
  storage.translation_cache[namespace] = storage.translation_cache[namespace] or {}
  storage.translation_cache[namespace][locale] = storage.translation_cache[namespace][locale] or {}
  storage.translation_cache[namespace][locale][internal_name] = translated
end

function TranslationCache:is_complete(namespace, locale)
  ensure_stores()
  local namespace_locales = storage.translated_locales[namespace]
  if namespace_locales == nil then
    return false
  end
  return namespace_locales[locale] == true
end

function TranslationCache:mark_complete(namespace, locale)
  ensure_stores()
  storage.translated_locales[namespace] = storage.translated_locales[namespace] or {}
  storage.translated_locales[namespace][locale] = true
end

-- Intentionally namespace-less: resets every namespace at once. Only called from
-- on_configuration_changed, where wiping all sources' cached translations is the desired
-- behavior, not just the caller's own namespace.
function TranslationCache:clear()
  storage.translation_cache = {}
  storage.translated_locales = {}
end

return TranslationCache
