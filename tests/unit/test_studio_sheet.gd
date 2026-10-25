extends GutTest

func _computer_cell(img: Image, col: int) -> PackedByteArray:
	return img.get_region(Rect2i(col * StudioSheet.CELL, 0, StudioSheet.CELL, StudioSheet.CELL)).get_data()

func test_build_is_deterministic() -> void:
	assert_true(StudioSheet.build().get_data() == StudioSheet.build().get_data())

func test_committed_png_matches_generator() -> void:
	var loaded := Image.load_from_file(ProjectSettings.globalize_path(StudioSheet.OUT_PATH))
	assert_not_null(loaded)
	loaded.convert(Image.FORMAT_RGBA8)
	var built := StudioSheet.build()
	assert_eq(loaded.get_size(), built.get_size())
	assert_true(loaded.get_data() == built.get_data())

func test_layout() -> void:
	var img := StudioSheet.build()
	assert_eq(img.get_size(), Vector2i(48, 32))
	assert_eq(img.get_format(), Image.FORMAT_RGBA8)
	for col: int in range(StudioSheet.COLS):
		var opaque := 0
		for y: int in range(StudioSheet.CELL):
			for x: int in range(StudioSheet.CELL):
				if img.get_pixel(col * StudioSheet.CELL + x, y).a > 0.0:
					opaque += 1
		assert_gte(opaque, 40, "computer cell %d" % col)
	assert_false(_computer_cell(img, 0) == _computer_cell(img, 1))
	assert_false(_computer_cell(img, 0) == _computer_cell(img, 2))
	assert_false(_computer_cell(img, 1) == _computer_cell(img, 2))
	for col: int in range(StudioSheet.COLS):
		for y: int in range(StudioSheet.CELL):
			for x: int in range(StudioSheet.CELL):
				assert_eq(img.get_pixel(col * StudioSheet.CELL + x, StudioSheet.CELL + y).a, 1.0)

func test_readme_states_own_work() -> void:
	var text := FileAccess.get_file_as_string("res://assets/art/studio/README.md").to_lower()
	assert_string_contains(text, "own work")
	assert_string_contains(text, "fictional")
