extends GutTest

const SCENE: PackedScene = preload("res://src/ui/office/office_scene.tscn")


func _scene() -> OfficeScene:
	var sc: OfficeScene = add_child_autofree(SCENE.instantiate()) as OfficeScene
	sc.configure(OfficeFixtures.offices(), OfficeFixtures.equipment_defs())
	return sc


func after_each() -> void:
	GameRunner.session = null


func _session(s: GameState) -> void:
	GameRunner.session = GameSession.new(s, Fixtures.tuning())


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
	await wait_process_frames(1)


func test_office_change_rebuilds_room() -> void:
	var sc := _scene()
	var s := _state()
	sc.refresh(s, Fixtures.tuning())
	OfficeFixtures.set_office(s, &"office_small")
	sc.refresh(s, Fixtures.tuning())
	assert_eq(sc.room().size_tiles, Vector2i(18, 9))
	assert_eq(sc.desk_count(), 5)
	await wait_process_frames(1)
	assert_eq(sc.get_node("RoomSlot").get_child_count(), 1)
	assert_eq(sc.get_node("Desks").get_child_count(), 5)


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


func test_points_gained_spawns_bubble_at_staff() -> void:
	var sc := _scene()
	var s := _state()
	_session(s)
	sc.refresh(s, Fixtures.tuning())
	EventBus.dispatch(&"points_gained", {"staff_id": s.owner.staff_id, "type": &"design", "amount": 3})
	var layer: BubbleLayer = sc.get_node("Bubbles")
	assert_eq(layer.live_count(), 1)
	assert_eq((layer.get_child(0) as Bubble).kind, &"design")


func test_bug_found_spawns_bug_bubble() -> void:
	var sc := _scene()
	var s := _state()
	_session(s)
	sc.refresh(s, Fixtures.tuning())
	EventBus.dispatch(&"bug_found", {"staff_id": s.owner.staff_id})
	var layer: BubbleLayer = sc.get_node("Bubbles")
	assert_eq(layer.live_count(), 1)
	assert_eq((layer.get_child(0) as Bubble).kind, &"bug")


func test_event_for_unshown_staff_spawns_nothing() -> void:
	var sc := _scene()
	var s := _state()
	_session(s)
	var loose: int = Fixtures.add_staff(s, {})
	var other: int = Fixtures.add_staff(s, {"company_id": 999, "seat_index": 1})
	var gone: int = Fixtures.add_worker(s, {})
	sc.refresh(s, Fixtures.tuning())
	Removal.remove_staff(s, gone)
	sc.refresh(s, Fixtures.tuning())
	var layer: BubbleLayer = sc.get_node("Bubbles")
	for sid: int in [loose, other, gone, 987654]:
		EventBus.dispatch(&"points_gained", {"staff_id": sid, "type": &"tech", "amount": 1})
		EventBus.dispatch(&"bug_found", {"staff_id": sid})
	EventBus.dispatch(&"points_gained", {})
	EventBus.dispatch(&"bug_found", {})
	assert_eq(layer.live_count(), 0)
	await wait_process_frames(1)


func test_game_loaded_rebuilds_from_new_session() -> void:
	var sc := _scene()
	var old: GameState = _state()
	_session(old)
	sc.refresh(old, Fixtures.tuning())
	var old_owner: int = old.owner.staff_id
	var old_extra: int = Fixtures.add_worker(old, {"seat_index": 1})
	sc.refresh(old, Fixtures.tuning())
	assert_not_null(sc.staff_sprite(old_owner))
	assert_not_null(sc.staff_sprite(old_extra))
	var fresh: GameState = Fixtures.new_state(2)
	OfficeFixtures.set_office(fresh, &"office_garage")
	for i: int in 5:
		fresh.alloc_id()
	var other: int = Fixtures.add_worker(fresh, {"seat_index": 1})
	assert_ne(other, old_extra)
	_session(fresh)
	EventBus.dispatch(&"game_loaded", {})
	assert_not_null(sc.staff_sprite(other))
	assert_null(sc.staff_sprite(old_extra))
	await wait_process_frames(1)
	assert_eq(sc.get_node("Staff").get_child_count(), 2)


func test_empty_scene_path_is_unknown_office() -> void:
	var sc := _scene()
	var offices: Dictionary[StringName, OfficeDef] = OfficeFixtures.offices()
	offices[&"office_garage"].scene_path = ""
	sc.configure(offices, OfficeFixtures.equipment_defs())
	sc.refresh(_state(), Fixtures.tuning())
	assert_null(sc.room())
	assert_eq(sc.desk_count(), 0)
