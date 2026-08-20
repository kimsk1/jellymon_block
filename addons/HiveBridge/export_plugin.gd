@tool
extends EditorPlugin

var export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	export_plugin = HiveAndroidExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null


class HiveAndroidExportPlugin extends EditorExportPlugin:
	const PLUGIN_NAME := "HiveBridge"
	const HIVE_VERSION := "26.4.0"
	const ADIZ_VERSION := "3.0.0"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var variant := "debug" if debug else "release"
		return PackedStringArray(["%s/bin/%s/%s-%s.aar" % [PLUGIN_NAME, variant, PLUGIN_NAME, variant]])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		# EditorExportPlugin은 Gradle의 platform(...) 문법을 표현할 수 없으므로
		# 앱 export에서는 BOM 대신 동일 버전을 각 artifact에 명시한다.
		return PackedStringArray([
			"com.com2us.android.hive:hive-sdk:%s" % HIVE_VERSION,
			"com.com2us.android.hive:hive-authv4-provider-google-credential-signin:%s" % HIVE_VERSION,
			"com.com2us.android.hive:hive-authv4-provider-google-playgames:%s" % HIVE_VERSION,
			"com.android.installreferrer:installreferrer:2.2",
			"com.com2us.android.adiz:hive-adiz:%s" % ADIZ_VERSION,
		])

	func _get_android_dependencies_maven_repos(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["https://maven.google.com", "https://repo.maven.apache.org/maven2"])

	func _get_name() -> String:
		return PLUGIN_NAME
