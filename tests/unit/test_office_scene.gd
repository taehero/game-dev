extends GutTest

const SCENE: PackedScene = preload("res://src/ui/office/office_scene.tscn")


func _scene() -> OfficeScene:
	var sc: OfficeScene = add_child_autofree(SCENE.instantiate()) as OfficeScene
	sc.configure(OfficeFixtures.offices(), OfficeFixtures.equipment_defs())
	return sc


func _state() -> GameState:
	var s: GameState = Fixtures.new_state(1)
	OfficeFixtures.set_office(s, &"office_garage")
	return s


func _crunching_project(s: GameState) -> int:
	return Fixtures.add_project(s, {"phase": Project.Phase.PRODUCTION, "crunch": true})


func test_builds_room_from_office_def() -> void:
	var sc := _scene()
	sc.refresh(_state(), Fixtures.tuning())
	assert_eq(sc.room().size_tiles, Vector2i(12, 8))


func test_desks_match_office_seats_and_positions() -> void:
	var sc := _scene()
	sc.refresh(_state(), Fixtures.tuning())
	assert_eq(sc.desk_count(), 2)
	for i: int in 2:
		assert_eq(sc.desk_at(i).position, sc.room().cell_to_local(OfficeRoom.GARAGE_DESKS[i]))


func test_computer_sprite_per_equipment_tier() -> void:
	var sc := _scene()
	var s := _state()
	sc.refresh(s, Fixtures.tuning())
	assert_eq(sc.desk_at(0).computer_tier, 1)
	assert_eq(sc.desk_at(1).computer_tier, 0)
	Fixtures.add_equipment(s, {"seat_index": 1, "def_id": &"equipment_fx_fast"})
	sc.refresh(s, Fixtures.tuning())
	assert_eq(sc.desk_at(1).computer_tier, 2)


func test_seated_staff_sprite_has_pose() -> void:
	var sc := _scene()
	var s := _state()
	var id: int = Fixtures.add_worker(s, {"seat_index": 1, "assigned_project_id": _crunching_project(s)})
	sc.refresh(s, Fixtures.tuning())
	var sprite: StaffSprite = sc.staff_sprite(id)
	assert_not_null(sprite)
	assert_eq(sprite.pose, StateQueries.StaffPose.CRUNCHING)
	assert_eq(sprite.position, sc.room().cell_to_local(OfficeRoom.GARAGE_DESKS[1] + Vector2i(0, 1)))


func test_unseated_staff_has_no_sprite() -> void:
	var sc := _scene()
	var s := _state()
	var id: int = Fixtures.add_staff(s, {})
	sc.refresh(s, Fixtures.tuning())
	assert_null(sc.staff_sprite(id))


func test_removed_staff_sprite_freed_on_refresh() -> void:
	var sc := _scene()
	var s := _state()
	var id: int = Fixtures.add_worker(s, {})
	sc.refresh(s, Fixtures.tuning())
	assert_not_null(sc.staff_sprite(id))
	Removal.remove_staff(s, id)
	sc.refresh(s, Fixtures.tuning())
	assert_null(sc.staff_sprite(id))


func test_office_change_rebuilds_room() -> void:
	var sc := _scene()
	var s := _state()
	sc.refresh(s, Fixtures.tuning())
	OfficeFixtures.set_office(s, &"office_small")
	sc.refresh(s, Fixtures.tuning())
	assert_eq(sc.room().size_tiles, Vector2i(18, 9))
	assert_eq(sc.desk_count(), 5)


func test_unknown_office_leaves_scene_empty() -> void:
	var sc := _scene()
	var s := _state()
	OfficeFixtures.set_office(s, &"office_nowhere")
	sc.refresh(s, Fixtures.tuning())
	assert_eq(sc.desk_count(), 0)
	assert_null(sc.room())
	assert_null(sc.staff_sprite(s.owner.staff_id))


func test_spawn_bubble_for_seated_staff_only() -> void:
	var sc := _scene()
	var s := _state()
	var loose: int = Fixtures.add_staff(s, {})
	sc.refresh(s, Fixtures.tuning())
	assert_true(sc.spawn_bubble(s.owner.staff_id, &"design"))
	assert_false(sc.spawn_bubble(loose, &"design"))
	assert_false(sc.spawn_bubble(-1, &"design"))
