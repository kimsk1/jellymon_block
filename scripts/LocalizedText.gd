extends RefCounted
## Presentation-only translation. Never apply this to account IDs or saved player input.
static var _locale := ""
static var _cache: Dictionary = {}
static var _patterns: Array = []

static func text(source: String) -> String:
	var locale := TranslationServer.get_locale()
	if locale.begins_with("ko") or source.is_empty(): return source
	if not _has_korean(source): return source
	if _locale != locale:
		_locale = locale
		_cache.clear()
	if _cache.has(source): return String(_cache[source])
	var result := String(TranslationServer.translate(source))
	if result == source and _has_korean(source):
		result = _translate_composed(source)
	if _cache.size() >= 2048: _cache.clear()
	_cache[source] = result
	return result

static func _has_korean(value: String) -> bool:
	for i in value.length():
		var code := value.unicode_at(i)
		if code >= 0xAC00 and code <= 0xD7A3: return true
	return false

static func _translate_composed(source: String) -> String:
	# Legacy save captions and baked level metadata may already contain formatted values.
	# Match complete templates only, then preserve the captured values.
	if _patterns.is_empty(): _build_patterns()
	for entry in _patterns:
		var found: RegExMatch = entry.regex.search(source)
		if found == null: continue
		var values: Array = []
		for i in entry.types.size():
			var value := found.get_string(i + 1)
			match entry.types[i]:
				"d": values.append(int(value))
				"f": values.append(float(value))
				_: values.append(text(value) if value != source else value)
		return String(TranslationServer.translate(entry.source)) % values
	for separator in ["\n", " · ", " → ", " / "]:
		if source.contains(separator):
			var parts := source.split(separator)
			for i in parts.size(): parts[i] = text(parts[i])
			return separator.join(parts)
	return source

static func _build_patterns() -> void:
	var file := FileAccess.open("res://assets/localization/en.json", FileAccess.READ)
	var catalog: Dictionary = JSON.parse_string(file.get_as_text()) if file else {}
	var token := RegEx.new()
	token.compile("%[0-9.]*[dsf]")
	for source in catalog:
		var matches := token.search(source)
		if matches == null or not _has_korean(source): continue
		var expression := "(?s)^"
		var offset := 0
		var types: Array[String] = []
		for item in token.search_all(source):
			expression += _escape_regex(source.substr(offset, item.get_start() - offset))
			var kind := item.get_string().right(1)
			types.append(kind)
			expression += "(-?[0-9]+)" if kind == "d" else ("(-?[0-9]+(?:\\.[0-9]+)?)" if kind == "f" else "(.+?)")
			offset = item.get_end()
		expression += _escape_regex(source.substr(offset)) + "$"
		var regex := RegEx.new()
		if regex.compile(expression) == OK:
			_patterns.append({"source": source, "regex": regex, "types": types})

static func _escape_regex(value: String) -> String:
	var result := ""
	for character in value:
		if character in ["\\", ".", "^", "$", "|", "?", "*", "+", "(", ")", "[", "]", "{", "}"]: result += "\\"
		result += character
	return result
