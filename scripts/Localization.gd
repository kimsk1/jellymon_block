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
const RUNTIME_MESSAGES := {
	"ko": {"일시정지":"일시정지", "잠깐 쉬어갈까요?":"잠깐 쉬어갈까요?", "계속하기":"계속하기", "같은 색 젤리몬부터 차례로 구조해요.":"같은 색 젤리몬부터 차례로 구조해요.", "젤리 아지트 앨범":"젤리 아지트 앨범", "구출 주민 %d/6 · 추억 %d개":"구출 주민 %d/6 · 추억 %d개", "함께 사는 친구들":"함께 사는 친구들", "최근 말랑 추억":"최근 말랑 추억", "구조대 배지":"구조대 배지", "달성":"달성", "젤리몬":"젤리몬", "모험에서 첫 주민을 구조하면 사진 카드가 열려요.":"모험에서 첫 주민을 구조하면 사진 카드가 열려요.", "첫 모험을 시작한 날":"첫 모험을 시작한 날"},
	"en": {"일시정지":"Pause", "잠깐 쉬어갈까요?":"Take a break?", "계속하기":"Resume", "같은 색 젤리몬부터 차례로 구조해요.":"Rescue matching Jellymon one color at a time.", "젤리 아지트 앨범":"Jelly Hideout Album", "구출 주민 %d/6 · 추억 %d개":"Residents %d/6 · %d memories", "함께 사는 친구들":"Friends at Home", "최근 말랑 추억":"Recent Memories", "구조대 배지":"Rescue Badges", "달성":"Complete", "젤리몬":"Jellymon", "모험에서 첫 주민을 구조하면 사진 카드가 열려요.":"Rescue your first resident to unlock a photo card.", "첫 모험을 시작한 날":"The day our first adventure began"},
	"ja": {"일시정지":"一時停止", "잠깐 쉬어갈까요?":"ひと休みしますか？", "계속하기":"つづける", "같은 색 젤리몬부터 차례로 구조해요.":"同じ色のジェリモンから順番に救出しよう。", "젤리 아지트 앨범":"ジェリーハウスアルバム", "구출 주민 %d/6 · 추억 %d개":"住民 %d/6・思い出 %d", "함께 사는 친구들":"一緒に暮らす仲間", "최근 말랑 추억":"最近の思い出", "구조대 배지":"救助隊バッジ", "달성":"達成", "젤리몬":"ジェリモン", "모험에서 첫 주민을 구조하면 사진 카드가 열려요.":"最初の住民を救出すると写真カードが開きます。", "첫 모험을 시작한 날":"最初の冒険を始めた日"},
	"zh_CN": {"일시정지":"暂停", "잠깐 쉬어갈까요?":"休息一下吗？", "계속하기":"继续", "같은 색 젤리몬부터 차례로 구조해요.":"按颜色依次救出同色果冻怪。", "젤리 아지트 앨범":"果冻小屋相册", "구출 주민 %d/6 · 추억 %d개":"居民 %d/6 · 回忆 %d", "함께 사는 친구들":"一起生活的朋友", "최근 말랑 추억":"最近的回忆", "구조대 배지":"救援队徽章", "달성":"达成", "젤리몬":"果冻怪", "모험에서 첫 주민을 구조하면 사진 카드가 열려요.":"救出第一位居民即可解锁照片卡。", "첫 모험을 시작한 날":"开始第一次冒险的那天"},
	"zh_TW": {"일시정지":"暫停", "잠깐 쉬어갈까요?":"休息一下嗎？", "계속하기":"繼續", "같은 색 젤리몬부터 차례로 구조해요.":"依顏色依序救出同色果凍怪。", "젤리 아지트 앨범":"果凍小屋相簿", "구출 주민 %d/6 · 추억 %d개":"居民 %d/6 · 回憶 %d", "함께 사는 친구들":"一起生活的朋友", "최근 말랑 추억":"最近的回憶", "구조대 배지":"救援隊徽章", "달성":"達成", "젤리몬":"果凍怪", "모험에서 첫 주민을 구조하면 사진 카드가 열려요.":"救出第一位居民即可解鎖照片卡。", "첫 모험을 시작한 날":"開始第一次冒險的那天"},
	"fr": {"일시정지":"Pause", "잠깐 쉬어갈까요?":"Faire une pause ?", "계속하기":"Continuer", "같은 색 젤리몬부터 차례로 구조해요.":"Sauvez les Jellymon de même couleur à tour de rôle.", "젤리 아지트 앨범":"Album du refuge", "구출 주민 %d/6 · 추억 %d개":"Résidents %d/6 · %d souvenirs", "함께 사는 친구들":"Amis du refuge", "최근 말랑 추억":"Souvenirs récents", "구조대 배지":"Badges de sauvetage", "달성":"Terminé", "젤리몬":"Jellymon", "모험에서 첫 주민을 구조하면 사진 카드가 열려요.":"Sauvez votre premier résident pour débloquer une photo.", "첫 모험을 시작한 날":"Le jour de notre première aventure"},
	"de": {"일시정지":"Pause", "잠깐 쉬어갈까요?":"Eine Pause machen?", "계속하기":"Fortsetzen", "같은 색 젤리몬부터 차례로 구조해요.":"Rette nacheinander Jellymon derselben Farbe.", "젤리 아지트 앨범":"Versteck-Album", "구출 주민 %d/6 · 추억 %d개":"Bewohner %d/6 · %d Erinnerungen", "함께 사는 친구들":"Freunde im Versteck", "최근 말랑 추억":"Neueste Erinnerungen", "구조대 배지":"Rettungsabzeichen", "달성":"Geschafft", "젤리몬":"Jellymon", "모험에서 첫 주민을 구조하면 사진 카드가 열려요.":"Rette den ersten Bewohner, um eine Fotokarte freizuschalten.", "첫 모험을 시작한 날":"Der Tag unseres ersten Abenteuers"},
	"es": {"일시정지":"Pausa", "잠깐 쉬어갈까요?":"¿Tomamos un descanso?", "계속하기":"Continuar", "같은 색 젤리몬부터 차례로 구조해요.":"Rescata por turnos a los Jellymon del mismo color.", "젤리 아지트 앨범":"Álbum del refugio", "구출 주민 %d/6 · 추억 %d개":"Residentes %d/6 · %d recuerdos", "함께 사는 친구들":"Amigos del refugio", "최근 말랑 추억":"Recuerdos recientes", "구조대 배지":"Insignias de rescate", "달성":"Completado", "젤리몬":"Jellymon", "모험에서 첫 주민을 구조하면 사진 카드가 열려요.":"Rescata al primer residente para desbloquear una foto.", "첫 모험을 시작한 날":"El día de nuestra primera aventura"},
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
		for key in parsed:
			translation.add_message(StringName(String(key)), String(parsed[key]))
		for key in RUNTIME_MESSAGES.get(locale, {}):
			translation.add_message(StringName(String(key)), String(RUNTIME_MESSAGES[locale][key]))
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
	var runtime_reference: Dictionary = RUNTIME_MESSAGES.get(DEFAULT_LOCALE, {})
	for locale in SUPPORTED_LOCALES:
		var runtime_locale: Dictionary = RUNTIME_MESSAGES.get(locale, {})
		for key in runtime_reference:
			if not runtime_locale.has(key) or String(runtime_locale[key]).is_empty():
				errors.append("%s runtime translation missing: %s" % [locale, key])
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
		for key in english_keys:
			if not parsed.has(key):
				errors.append("%s translation missing: %s" % [locale, key])
		for key in parsed:
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
