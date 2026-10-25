extends GutTest


func test_hire_adds_staff_with_skills_in_range() -> void:
	var s := Fixtures.new_state(3)
	var t := Fixtures.tuning()
	var cmd := HireStaffCommand.new(s.player_company_id, "Ada", 800)
	assert_true(cmd.validate(s, t).ok)
	var ctx := TickContext.new(s, t)
	cmd.apply(ctx)
	assert_eq(s.staff.size(), 2)
	var st: Staff = s.staff[s.next_id - 1]
	for k: StringName in [&"design", &"tech", &"art", &"audio"]:
		assert_between(st.skills[k], t.hire_skill_min, t.hire_skill_max)
	assert_eq(st.salary, 800)
	assert_eq(st.company_id, s.player_company_id)
	assert_eq(ctx.events[0]["name"], &"staff_hired")
	assert_eq(ctx.events[0]["payload"]["staff_id"], st.id)


func test_hire_is_deterministic_for_same_seed() -> void:
	var a := Fixtures.new_state(3)
	var b := Fixtures.new_state(3)
	var t := Fixtures.tuning()
	HireStaffCommand.new(a.player_company_id, "Ada", 800).apply(TickContext.new(a, t))
	HireStaffCommand.new(b.player_company_id, "Ada", 800).apply(TickContext.new(b, t))
	assert_eq(StateHash.of(a), StateHash.of(b))


func test_hire_takes_the_free_garage_seat() -> void:
	var s := Fixtures.new_state(3)
	var t := Fixtures.tuning()
	var ctx := TickContext.new(s, t)
	HireStaffCommand.new(s.player_company_id, "Ada", 800).apply(ctx)
	var st: Staff = s.staff[s.next_id - 1]
	assert_eq(st.seat_index, 1)
	assert_eq(st.hired_week, 0)
	assert_eq(st.last_raise_week, 0)
	assert_eq(st.level, Staff.Level.JUNIOR)
	assert_eq(st.exp, {&"art": 0, &"audio": 0, &"design": 0, &"tech": 0})


func test_hire_rejected_when_no_free_seat() -> void:
	var s := Fixtures.new_state(3)
	var t := Fixtures.tuning()
	HireStaffCommand.new(s.player_company_id, "Ada", 800).apply(TickContext.new(s, t))
	var r := HireStaffCommand.new(s.player_company_id, "Bo", 800).validate(s, t)
	assert_eq(r.reason_key, &"error.no_free_seat")


func test_hire_rejected_for_unknown_company() -> void:
	var s := Fixtures.new_state(3)
	var r := HireStaffCommand.new(999, "X", 800).validate(s, Fixtures.tuning())
	assert_eq(r.reason_key, &"error.company_not_found")


func test_hire_rejected_for_zero_salary() -> void:
	var s := Fixtures.new_state(3)
	var r := HireStaffCommand.new(s.player_company_id, "X", 0).validate(s, Fixtures.tuning())
	assert_eq(r.reason_key, &"error.invalid_salary")


func test_place_equipment_validates_def_and_seat() -> void:
	var s := Fixtures.new_state(1)
	var t := Fixtures.tuning()
	var owner_eq: Equipment = s.equipment[s.sorted_ids(s.equipment)[0]]
	var def_id: StringName = owner_eq.def_id
	assert_false(PlaceEquipmentCommand.new(1, &"nope", 1).validate(s, t).ok)
	assert_false(PlaceEquipmentCommand.new(1, def_id, 0).validate(s, t).ok, "seat taken")
	assert_false(PlaceEquipmentCommand.new(1, def_id, 99).validate(s, t).ok, "seat out of range")
	var cmd := PlaceEquipmentCommand.new(1, def_id, 1)
	assert_true(cmd.validate(s, t).ok)
	cmd.apply(TickContext.new(s, t))
	assert_eq(s.equipment[s.next_id - 1].value, Fixtures.content().equipment[def_id].price)
