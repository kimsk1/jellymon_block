extends SceneTree
const Expiry = preload("res://scripts/DebugBuildExpiry.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for dates in [["2026-09-16T10:00:00", "2026-10-16T10:00:00"], ["2026-01-31T10:00:00", "2026-02-28T10:00:00"], ["2028-01-31T10:00:00", "2028-02-29T10:00:00"], ["2026-12-31T10:00:00", "2027-01-31T10:00:00"]]:
		var built := Time.get_unix_time_from_datetime_string(dates[0])
		var metadata := Expiry.build_metadata(built)
		assert(metadata.built_at == built)
		assert(metadata.expires_at == Time.get_unix_time_from_datetime_string(dates[1]))
	var guard := Expiry.new()
	root.add_child(guard)
	assert(guard.start(), "Desktop/editor must be unrestricted without metadata")
	guard.expires_at = int(Time.get_unix_time_from_system()) + 60
	guard._check_expiry()
	assert(not guard.blocked and not paused)
	guard.expires_at = int(Time.get_unix_time_from_system())
	guard._check_expiry()
	assert(guard.blocked and paused, "Block exactly at expiry")
	guard._check_expiry()
	assert(guard.get_child_count() == 1, "Only one expiry overlay")
	paused = false
	guard.free()
	var missing := Expiry.new()
	root.add_child(missing)
	missing._check_expiry()
	assert(missing.blocked, "Invalid expiry must fail closed when enforced")
	paused = false
	missing.free()
	print("PASS: calendar month, year rollover, leap year, desktop exemption, expiry boundary and overlay")
	quit()
