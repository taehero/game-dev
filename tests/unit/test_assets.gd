extends GutTest

func _pack_dirs() -> Array[String]:
	var out: Array[String] = []
	for d: String in DirAccess.get_directories_at("res://assets/art"):
		out.append("res://assets/art".path_join(d))
	return out

func test_at_least_one_art_pack() -> void:
	assert_gt(_pack_dirs().size(), 0)

func test_every_art_pack_has_cc0_license() -> void:
	for dir: String in _pack_dirs():
		if dir.get_file() == "studio":
			var readme := dir.path_join("README.md")
			assert_true(FileAccess.file_exists(readme), readme)
			assert_string_contains(FileAccess.get_file_as_string(readme).to_lower(), "own work")
			continue
		var path := dir.path_join("License.txt")
		assert_true(FileAccess.file_exists(path), path)
		assert_string_contains(FileAccess.get_file_as_string(path).to_upper(), "CC0", false)

func test_credits_lists_every_pack_and_the_font() -> void:
	var credits := FileAccess.get_file_as_string("res://assets/CREDITS.md")
	for dir: String in _pack_dirs():
		assert_string_contains(credits, dir.get_file())
	assert_string_contains(credits, "NotoSansThai-Variable.ttf")
	assert_string_contains(credits, "SIL Open Font License 1.1")

func test_pixel_textures_import_lossless_without_mipmaps() -> void:
	for dir: String in _pack_dirs():
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".png.import"):
				var cfg := ConfigFile.new()
				assert_eq(cfg.load(dir.path_join(f)), OK)
				assert_eq(int(cfg.get_value("params", "compress/mode")), 0, f)
				assert_false(bool(cfg.get_value("params", "mipmaps/generate")), f)

func test_office_art_cells_inside_sheet() -> void:
	var size: Vector2i = (load(OfficeArt.SHEET_PATH) as Texture2D).get_size()
	for cell: Vector2i in OfficeArt.all_cells():
		assert_true(Rect2i(Vector2i.ZERO, size).encloses(OfficeArt.region(cell)), str(cell))

func test_computer_cell_clamps_tier() -> void:
	assert_eq(OfficeArt.computer_cell(0), OfficeArt.COMPUTERS[0])
	assert_eq(OfficeArt.computer_cell(99), OfficeArt.COMPUTERS[OfficeArt.COMPUTERS.size() - 1])

func test_tileset_has_floor_and_wall_tiles() -> void:
	var src := OfficeArt.tileset().get_source(0) as TileSetAtlasSource
	assert_eq(OfficeArt.tileset().tile_size, Vector2i(16, 16))
	for cell: Vector2i in [OfficeArt.FLOORS[&"concrete"], OfficeArt.FLOORS[&"wood"], OfficeArt.WALL_FACE]:
		assert_true(src.has_tile(cell), str(cell))
