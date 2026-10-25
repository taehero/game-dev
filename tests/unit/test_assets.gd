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

func test_no_one_bit_pack() -> void:
	assert_false(DirAccess.dir_exists_absolute("res://assets/art/kenney_1bit"))
	assert_false(FileAccess.get_file_as_string("res://assets/CREDITS.md").contains("1-Bit"))

func test_every_ref_inside_its_sheet() -> void:
	for ref: Vector3i in OfficeArt.all_refs():
		var size: Vector2i = (load(OfficeArt.SHEET_PATHS[ref.x]) as Texture2D).get_size()
		assert_true(Rect2i(Vector2i.ZERO, size).encloses(OfficeArt.region(ref)), str(ref))

func test_indoor_separation_is_one() -> void:
	assert_eq(OfficeArt.region(Vector3i(OfficeArt.Sheet.INDOOR, 1, 2)).position, Vector2i(17, 34))

func test_tileset_sources_match_sheets() -> void:
	var ts := OfficeArt.tileset()
	assert_eq(ts.tile_size, Vector2i(16, 16))
	for sheet: int in OfficeArt.TILE_SHEETS:
		var src := ts.get_source(sheet) as TileSetAtlasSource
		assert_not_null(src)
		assert_eq(src.separation, OfficeArt.SEPARATIONS[sheet])
	var refs: Array[Vector3i] = []
	refs.append_array(OfficeArt.FLOORS.values())
	refs.append_array(OfficeArt.WALL_UPPER)
	refs.append_array(OfficeArt.WALL_LOWER)
	refs.append_array([OfficeArt.WALL_TOP, OfficeArt.GROUND])
	for ref: Vector3i in OfficeArt.all_refs():
		if ref.x in OfficeArt.TILE_SHEETS:
			refs.append(ref)
	for ref: Vector3i in refs:
		var src := ts.get_source(ref.x) as TileSetAtlasSource
		assert_true(src.has_tile(Vector2i(ref.y, ref.z)), str(ref))

func test_computer_ref_clamps_tier() -> void:
	assert_eq(OfficeArt.computer_ref(0), OfficeArt.COMPUTERS[0])
	assert_eq(OfficeArt.computer_ref(99), OfficeArt.COMPUTERS[OfficeArt.COMPUTERS.size() - 1])

func test_staff_backs_are_urban_back_column() -> void:
	assert_eq(OfficeArt.STAFF_BACKS.size(), 5)
	for ref: Vector3i in OfficeArt.STAFF_BACKS:
		assert_eq(ref.x, OfficeArt.Sheet.URBAN)
		assert_eq(ref.y, 25)

func test_chair_overlay_clips_top() -> void:
	var want := Rect2(Vector2(OfficeArt.region(OfficeArt.CHAIR).position + Vector2i(0, 6)), Vector2(16, 10))
	assert_eq(OfficeArt.chair_overlay().region, want)

func test_emotes_cover_bubble_kinds() -> void:
	assert_eq(OfficeArt.EMOTES.keys(), [&"design", &"tech", &"art", &"audio", &"bug"])
