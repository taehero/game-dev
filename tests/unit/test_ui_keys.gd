extends GutTest


func _files(dir: String, out: Array[String]) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		_files(dir.path_join(d), out)


func test_every_literal_key_in_ui_source_exists() -> void:
	var re := RegEx.new()
	re.compile("&?\"((?:ui|error|event)\\.[a-z0-9_.]+[a-z0-9_%.]*)\"")
	var files: Array[String] = []
	_files("res://src/ui", files)
	var saved: String = TranslationServer.get_locale()
	var checked: int = 0
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		for m: RegExMatch in re.search_all(text):
			var key: String = m.get_string(1)
			if key.contains("%") or key.ends_with("."):
				continue
			checked += 1
			for loc: String in ["en", "th"]:
				TranslationServer.set_locale(loc)
				assert_ne(TranslationServer.translate(key), key, "%s missing in %s (%s)" % [key, loc, path])
	TranslationServer.set_locale(saved)
	assert_gt(checked, 20)
