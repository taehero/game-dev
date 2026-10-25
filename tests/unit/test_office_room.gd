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

const GARAGE := "res://src/ui/office/rooms/garage_room.tscn"
const SMALL := "res://src/ui/office/rooms/small_office_room.tscn"

func test_prepainted_floor_is_kept() -> void:
	var r: OfficeRoom = load(GARAGE).instantiate()
	var fl := r.get_node("Floor") as TileMapLayer
	fl.tile_set = OfficeArt.tileset()
	OfficeArt.paint(fl, Vector2i(1, 2), OfficeArt.FLOORS[&"wood"])
	add_child_autofree(r)
	assert_eq(fl.get_used_cells().size(), 1)
	assert_eq(r.get_node("Walls").get_used_cells().size(), 0)

func _atlas(layer: TileMapLayer, cell: Vector2i) -> Vector3i:
	var a := layer.get_cell_atlas_coords(cell)
	return Vector3i(layer.get_cell_source_id(cell), a.x, a.y)

func test_walls_paint_brick_rows_and_wall_tops() -> void:
	var walls := _room(GARAGE).get_node("Walls") as TileMapLayer
	assert_eq(walls.get_cell_source_id(Vector2i(0, 0)), OfficeArt.Sheet.CITY)
	assert_eq(walls.get_cell_atlas_coords(Vector2i(0, 0)), Vector2i(9, 6))
	assert_eq(walls.get_cell_atlas_coords(Vector2i(1, 0)), Vector2i(10, 6))
	assert_eq(walls.get_cell_atlas_coords(Vector2i(0, 1)), Vector2i(9, 8))
	assert_eq(_atlas(walls, Vector2i(0, 3)), OfficeArt.WALL_TOP)
	assert_eq(_atlas(walls, Vector2i(5, 7)), OfficeArt.WALL_TOP)

func test_ground_rings_the_room() -> void:
	var ground := _room(GARAGE).get_node("Ground") as TileMapLayer
	assert_eq(ground.get_used_cells().size(), (12 + 10) * (8 + 6) - 12 * 8)
	assert_eq(_atlas(ground, Vector2i(-5, -3)), OfficeArt.GROUND)
	assert_eq(ground.get_cell_source_id(Vector2i(0, 0)), -1)

func test_decor_avoids_desks_chairs_and_computers() -> void:
	for pair: Array in [[GARAGE, OfficeRoom.GARAGE_DESKS], [SMALL, OfficeRoom.SMALL_OFFICE_DESKS]]:
		var r := _room(pair[0])
		var forbidden: Array[Vector2i] = []
		for d: Vector2i in pair[1]:
			forbidden.append_array([d, d + Vector2i(1, 0), d + Vector2i(-1, 0), d + Vector2i(0, 1), d + Vector2i(0, -1)])
		for cell: Vector2i in OfficeRoom.DECOR[r.decor_set]:
			var prop: StringName = OfficeRoom.DECOR[r.decor_set][cell]
			var sz := OfficeArt.prop_size(prop)
			for dx: int in range(sz.x):
				for dy: int in range(sz.y):
					var c := cell + Vector2i(dx, dy)
					assert_false(c in forbidden, "%s %s" % [prop, c])
					var ok := r.is_floor(c) or (c.y <= 1 and c.x >= 0 and c.x < r.size_tiles.x)
					assert_true(ok, "%s %s" % [prop, c])

func test_decor_painted() -> void:
	var decor := _room(GARAGE).get_node("Decor") as TileMapLayer
	var shelf: Vector3i = OfficeArt.PROPS[&"shelf"]
	assert_eq(_atlas(decor, Vector2i(5, 2)), shelf)
	assert_eq(_atlas(decor, Vector2i(6, 2)), shelf + Vector3i(0, 1, 0))
