extends GutTest

func _room(path: String) -> OfficeRoom:
	return add_child_autofree(load(path).instantiate()) as OfficeRoom

func test_garage_size_and_floor_rect() -> void:
	var r := _room("res://src/ui/office/rooms/garage_room.tscn")
	assert_eq(r.size_tiles, Vector2i(12, 8))
	assert_eq(r.pixel_size(), Vector2i(192, 128))
	assert_eq(r.get_node("Floor").get_used_cells().size(), 10 * 5)
	assert_true(r.is_floor(Vector2i(1, 2)))
	assert_false(r.is_floor(Vector2i(0, 2)))
	assert_false(r.is_floor(Vector2i(5, 1)))

func test_small_office_size() -> void:
	var r := _room("res://src/ui/office/rooms/small_office_room.tscn")
	assert_eq(r.size_tiles, Vector2i(18, 9))
	assert_eq(r.get_node("Floor").get_used_cells().size(), 16 * 6)

func test_published_desks_and_chairs_are_on_floor() -> void:
	for pair: Array in [["res://src/ui/office/rooms/garage_room.tscn", OfficeRoom.GARAGE_DESKS],
			["res://src/ui/office/rooms/small_office_room.tscn", OfficeRoom.SMALL_OFFICE_DESKS]]:
		var r := _room(pair[0])
		for cell: Vector2i in pair[1]:
			assert_true(r.is_floor(cell), "desk %s" % cell)
			assert_true(r.is_floor(cell + Vector2i(0, 1)), "chair %s" % cell)

func test_cell_to_local_is_tile_centre() -> void:
	var r := _room("res://src/ui/office/rooms/garage_room.tscn")
	assert_eq(r.cell_to_local(Vector2i(3, 3)), Vector2(56, 56))

func test_prepainted_floor_is_kept() -> void:
	var r: OfficeRoom = load("res://src/ui/office/rooms/garage_room.tscn").instantiate()
	(r.get_node("Floor") as TileMapLayer).tile_set = OfficeArt.tileset()
	(r.get_node("Floor") as TileMapLayer).set_cell(Vector2i(1, 2), 0, OfficeArt.FLOORS[&"wood"])
	add_child_autofree(r)
	assert_eq(r.get_node("Floor").get_used_cells().size(), 1)

func test_backing_rects_sit_under_layers_with_floor_colour() -> void:
	var g := _room("res://src/ui/office/rooms/garage_room.tscn")
	var w := _room("res://src/ui/office/rooms/small_office_room.tscn")
	for r: OfficeRoom in [g, w]:
		var wall_back := r.get_node("WallBacking") as ColorRect
		var floor_back := r.get_node("FloorBacking") as ColorRect
		assert_eq(wall_back.size, Vector2(r.pixel_size()))
		assert_eq(floor_back.position, Vector2(16, 32))
		assert_eq(floor_back.size, Vector2((r.size_tiles.x - 2) * 16, (r.size_tiles.y - 2) * 16))
		assert_lt(wall_back.get_index(), r.get_node("Floor").get_index())
		assert_lt(floor_back.get_index(), r.get_node("Floor").get_index())
	assert_ne((g.get_node("FloorBacking") as ColorRect).color, (w.get_node("FloorBacking") as ColorRect).color)
