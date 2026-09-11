extends Node
## 사용자 문구를 코드와 분리해 JSON 카탈로그에서 Godot TranslationServer로 공급한다.

signal language_changed(locale: String)

const DEFAULT_LOCALE := "en"
const SYSTEM_LANGUAGE := "system"
const STORY_CATALOG_PATH := "res://assets/localization/story.json"
const SUPPORTED_LOCALES := ["ko", "en", "ja", "zh_CN", "zh_TW", "fr", "de", "es"]
const CATALOGS := {
	"ko": "res://assets/localization/ko.json",
	"en": "res://assets/localization/en.json",
	"ja": "res://assets/localization/ja.json",
	"zh_CN": "res://assets/localization/zh_CN.json",
	"zh_TW": "res://assets/localization/zh_TW.json",
	"fr": "res://assets/localization/fr.json",
	"de": "res://assets/localization/de.json",
	"es": "res://assets/localization/es.json",
}


var selected_language := SYSTEM_LANGUAGE
var current_locale := DEFAULT_LOCALE


func _enter_tree() -> void:
	_configure_font_fallbacks()
	_install_catalogs()
	apply_language(SYSTEM_LANGUAGE)


func _configure_font_fallbacks() -> void:
	## Jua의 분위기는 유지하고, 미포함 일본어·중국어 글리프만 기기 글꼴로 보완한다.
	var ui_font := load("res://assets/fonts/Jua-Regular.ttf") as Font
	if ui_font == null:
		return
	var system_fallback := SystemFont.new()
	system_fallback.font_names = PackedStringArray([
		"Noto Sans CJK KR", "Noto Sans CJK JP", "Noto Sans CJK SC", "Noto Sans CJK TC",
		"Apple SD Gothic Neo", "Hiragino Sans", "PingFang SC", "PingFang TC", "sans-serif",
	])
	system_fallback.allow_system_fallback = true
	ui_font.fallbacks = [system_fallback]


func _install_catalogs() -> void:
	var english_file := FileAccess.open(String(CATALOGS[DEFAULT_LOCALE]), FileAccess.READ)
	var english: Dictionary = JSON.parse_string(english_file.get_as_text()) if english_file else {}
	var story_file := FileAccess.open(STORY_CATALOG_PATH, FileAccess.READ)
	var story = JSON.parse_string(story_file.get_as_text()) if story_file else {}
	for locale in CATALOGS:
		var file := FileAccess.open(String(CATALOGS[locale]), FileAccess.READ)
		if file == null:
			push_error("Missing localization catalog: %s" % CATALOGS[locale])
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			push_error("Invalid localization catalog: %s" % CATALOGS[locale])
			continue
		var translation := Translation.new()
		translation.locale = String(locale)
		# Every locale inherits reviewed English copy; locale-specific copy overrides it.
		for key in english:
			translation.add_message(StringName(String(key)), String(english[key]))
		for key in parsed:
			translation.add_message(StringName(String(key)), String(parsed[key]))
		if story is Dictionary:
			for key in story.get(locale, {}):
				translation.add_message(StringName(String(key)), String(story[locale][key]), &"story")
		TranslationServer.add_translation(translation)


func apply_language(preference: String) -> String:
	selected_language = preference if preference == SYSTEM_LANGUAGE or SUPPORTED_LOCALES.has(preference) else SYSTEM_LANGUAGE
	current_locale = _system_locale() if selected_language == SYSTEM_LANGUAGE else selected_language
	TranslationServer.set_locale(current_locale)
	language_changed.emit(current_locale)
	return current_locale


func _system_locale() -> String:
	var system_locale := OS.get_locale().replace("-", "_")
	var language := OS.get_locale_language().to_lower()
	if language == "ko":
		return "ko"
	if language == "ja":
		return "ja"
	if language == "zh":
		var normalized := system_locale.to_lower()
		if normalized.contains("hant") or normalized.begins_with("zh_tw") or normalized.begins_with("zh_hk") or normalized.begins_with("zh_mo"):
			return "zh_TW"
		return "zh_CN"
	if SUPPORTED_LOCALES.has(language):
		return language
	return DEFAULT_LOCALE


func option_codes() -> Array[String]:
	return [SYSTEM_LANGUAGE, "ko", "en", "ja", "zh_CN", "zh_TW", "fr", "de", "es"]


func option_labels() -> Array[String]:
	return [tr("시스템 언어"), "한국어", "English", "日本語", "简体中文", "繁體中文", "Français", "Deutsch", "Español"]


func option_index(preference: String) -> int:
	return maxi(0, option_codes().find(preference))


func validate_catalogs() -> PackedStringArray:
	var errors := PackedStringArray()
	errors.append_array(_validate_story_catalog())
	var english_file := FileAccess.open(String(CATALOGS[DEFAULT_LOCALE]), FileAccess.READ)
	if english_file == null:
		errors.append("localization catalog missing: %s" % DEFAULT_LOCALE)
		return errors
	var english_keys = JSON.parse_string(english_file.get_as_text())
	if not english_keys is Dictionary:
		errors.append("localization catalog invalid: %s" % DEFAULT_LOCALE)
		return errors
	for locale in CATALOGS:
		var file := FileAccess.open(String(CATALOGS[locale]), FileAccess.READ)
		if file == null:
			errors.append("localization catalog missing: %s" % locale)
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			errors.append("localization catalog invalid: %s" % locale)
			continue
		for key in parsed:
			if String(parsed[key]).is_empty():
				errors.append("%s empty translation: %s" % [locale, key])
			if not english_keys.has(key):
				errors.append("%s translation has unknown key: %s" % [locale, key])
	return errors


func _validate_story_catalog() -> PackedStringArray:
	var errors := PackedStringArray()
	var file := FileAccess.open(STORY_CATALOG_PATH, FileAccess.READ)
	var catalog = JSON.parse_string(file.get_as_text()) if file else null
	if not catalog is Dictionary:
		return PackedStringArray(["story localization catalog missing or invalid"])
	var sources := {}
	for key in ["젤리몬 이야기", "구출 대원", "마음별 원정대 · LEVEL %d", "▼ %.1f초 후 다음 · 탭해서 계속"]:
		sources[key] = true
	var manifest := ScenarioCatalog.manifest()
	for speaker in manifest.get("cast", {}).values():
		if speaker.name != "{player_name}":
			sources[speaker.name] = true
	for entry in manifest.get("files", []):
		_collect_story_sources(ScenarioCatalog._read_json(entry.path), sources)
	var placeholders := RegEx.new()
	placeholders.compile("\\{[a-z_]+\\}|%[0-9.]*[dsf]")
	for locale in SUPPORTED_LOCALES:
		var messages = catalog.get(locale, {})
		if not messages is Dictionary:
			errors.append("invalid story locale: %s" % locale)
			continue
		for source in sources:
			var translated := String(messages.get(source, ""))
			if translated.is_empty():
				errors.append("%s story translation missing: %s" % [locale, source])
				continue
			var expected: Array[String] = []
			var actual: Array[String] = []
			for token in placeholders.search_all(source): expected.append(token.get_string())
			for token in placeholders.search_all(translated): actual.append(token.get_string())
			expected.sort()
			actual.sort()
			if expected != actual:
				errors.append("%s story placeholder mismatch: %s" % [locale, source])
			if locale != "ko" and translated == source and source != "{player_name}":
				errors.append("%s untranslated story: %s" % [locale, source])
	return errors


func _collect_story_sources(value: Variant, sources: Dictionary) -> void:
	if value is Array:
		for child in value: _collect_story_sources(child, sources)
	elif value is Dictionary:
		for key in value:
			if key in ["title", "subtitle", "text"] and value[key] is String:
				sources[value[key]] = true
			else:
				_collect_story_sources(value[key], sources)
