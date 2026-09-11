extends RefCounted
## 원본 레벨을 유지하면서 캠페인 표시와 초반 제한시간을 적용한다.

const EarlyCampaignCatalogLib = preload("res://scripts/EarlyCampaignCatalog.gd")

static func apply_early_campaign(source: Dictionary, level_number: int, chapter_title: String) -> Dictionary:
	var design := EarlyCampaignCatalogLib.design_for_level(level_number)
	if design.is_empty():
		return source
	var level := source.duplicate(true)
	level["campaign_arc"] = String(design.get("arc", ""))
	level["campaign_role"] = String(design.get("role", ""))
	# 첫 20레벨은 규칙을 읽고 직접 시험할 시간을 보장한다. 자동 생성기의
	# 급격한 타이머 하락은 첫 두 챕터가 끝난 뒤부터 적용한다.
	if level_number <= 4:
		level["time"] = maxf(float(level.get("time", 0.0)), 95.0)
	elif level_number <= 9:
		level["time"] = float(level.get("time", 0.0)) + 8.0
	elif level_number == 10:
		level["time"] = float(level.get("time", 0.0)) + 14.0
	elif level_number <= 19:
		level["time"] = float(level.get("time", 0.0)) + 10.0
	elif level_number == 20:
		level["time"] = float(level.get("time", 0.0)) + 18.0
	level["onboarding_phase"] = (
		"touch" if level_number <= 4 else
		"confidence" if level_number <= 10 else
		"strategy" if level_number <= 20 else "campaign"
	)
	var signature: Dictionary = design.get("signature", {})
	if not signature.is_empty():
		level["signature"] = signature.duplicate(true)
		level["name"] = "%s · %s" % [chapter_title, String(signature.get("title", level.get("name", "구조 작전")))]
		level["hint"] = String(signature.get("objective", level.get("hint", "")))
	return level


static func apply_long_campaign(source: Dictionary, level_number: int) -> Dictionary:
	if level_number <= 300:
		return source
	var level := source.duplicate(true)
	var arcs := [
		[301, 500, "복구 마을 원정", "다섯 지역의 구조 거점을 이어 주세요", "#62b879"],
		[501, 750, "차원 여행로", "포털과 무너지는 길의 구조 표식을 모아 주세요", "#5aa9d6"],
		[751, 1000, "전설의 시간 원정", "천 번째 마음까지 구조 기록을 완성해 주세요", "#9a72cf"],
	]
	for arc in arcs:
		if level_number < int(arc[0]) or level_number > int(arc[1]):
			continue
		level["campaign_arc"] = String(arc[2])
		level["campaign_role"] = String(arc[3])
		level["campaign_progress"] = level_number - int(arc[0]) + 1
		level["campaign_total"] = int(arc[1]) - int(arc[0]) + 1
		if level_number % 50 == 0:
			level["signature"] = {
				"title": "%s 거점" % String(arc[2]),
				"eyebrow": "MASTER EXPEDITION · LEVEL %d" % level_number,
				"objective": String(arc[3]),
				"reward_line": "%d번째 구조 표식이 원정 지도에 새겨졌어요!" % level_number,
				"accent": String(arc[4]),
			}
		return level
	return level
