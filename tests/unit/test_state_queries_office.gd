extends GutTest


func _views(s: GameState, office: OfficeDef = null) -> Array[SeatView]:
	if office == null:
		office = OfficeFixtures.garage()
	return StateQueries.seat_views(s, office, OfficeFixtures.equipment_defs(), Fixtures.tuning())


func _garage_state() -> GameState:
	var s: GameState = Fixtures.new_state(1)
	OfficeFixtures.set_office(s, &"office_garage")
	return s


func test_one_view_per_seat_with_desk_cells() -> void:
	var views := _views(_garage_state())
	assert_eq(views.size(), 2)
	for i: int in 2:
		assert_eq(views[i].desk_cell, OfficeRoom.GARAGE_DESKS[i])
		assert_eq(views[i].seat_index, i)


func test_owner_on_seat_zero() -> void:
	var s := _garage_state()
	var views := _views(s)
	assert_eq(views[0].staff_id, s.owner.staff_id)
	assert_eq(views[0].computer_tier, 1)
	assert_eq(views[1].staff_id, -1)
	assert_eq(views[1].computer_tier, 0)


func test_seated_staff_and_computer_tier() -> void:
	var s := _garage_state()
	var id: int = Fixtures.add_staff(s, {"seat_index": 1})
	Fixtures.add_equipment(s, {"seat_index": 1, "def_id": &"equipment_fx_fast"})
	var views := _views(s)
	assert_eq(views[1].staff_id, id)
	assert_eq(views[1].computer_tier, 2)


func test_seat_without_computer_forces_idle() -> void:
	var s := _garage_state()
	var pid: int = Fixtures.add_project(s, {"phase": Project.Phase.PRODUCTION})
	Fixtures.add_staff(s, {"seat_index": 1, "assigned_project_id": pid})
	assert_eq(_views(s)[1].pose, StateQueries.StaffPose.IDLE)
	Fixtures.add_equipment(s, {"seat_index": 1, "def_id": &"equipment_micro_1980"})
	assert_eq(_views(s)[1].pose, StateQueries.StaffPose.WORKING)


func test_out_of_range_seat_ignored() -> void:
	var s := _garage_state()
	var id: int = Fixtures.add_staff(s, {"seat_index": 7})
	Fixtures.add_equipment(s, {"seat_index": 7})
	for v: SeatView in _views(s):
		assert_ne(v.staff_id, id)
	assert_eq(_views(s).size(), 2)


func test_shared_seat_lowest_id_wins() -> void:
	var s := _garage_state()
	var a: int = Fixtures.add_staff(s, {"seat_index": 1})
	Fixtures.add_staff(s, {"seat_index": 1})
	assert_eq(_views(s)[1].staff_id, a)


func test_storage_and_other_company_equipment_ignored() -> void:
	var s := _garage_state()
	var before: Array[SeatView] = _views(s)
	Fixtures.add_equipment(s, {"seat_index": -1, "def_id": &"equipment_fx_fast"})
	Fixtures.add_equipment(s, {"seat_index": 1, "company_id": 999, "def_id": &"equipment_fx_fast"})
	var views := _views(s)
	assert_eq(views[1].computer_tier, 0)
	assert_eq(views[0].computer_tier, 1)
	for i: int in views.size():
		assert_eq(views[i].computer_tier, before[i].computer_tier)


func test_two_machines_on_one_seat_lowest_id_wins() -> void:
	var s := _garage_state()
	Fixtures.add_equipment(s, {"seat_index": 1, "def_id": &"equipment_micro_1980"})
	Fixtures.add_equipment(s, {"seat_index": 1, "def_id": &"equipment_fx_fast"})
	assert_eq(_views(s)[1].computer_tier, 1)


func test_other_company_staff_ignored() -> void:
	var s := _garage_state()
	Fixtures.add_staff(s, {"seat_index": 1, "company_id": 999})
	assert_eq(_views(s)[1].staff_id, -1)


func test_unknown_def_id_gives_tier_zero() -> void:
	var s := _garage_state()
	Fixtures.add_equipment(s, {"seat_index": 1, "def_id": &"equipment_nope"})
	assert_eq(_views(s)[1].computer_tier, 0)


func test_player_office_id() -> void:
	var s := _garage_state()
	assert_eq(StateQueries.player_office_id(s), &"office_garage")
	s.player_company_id = 12345
	assert_eq(StateQueries.player_office_id(s), &"")
