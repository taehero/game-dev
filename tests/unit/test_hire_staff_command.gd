extends GutTest


func test_hire_adds_staff_with_skills_in_range() -> void:
	var s := Fixtures.new_state(3)
	var t := Fixtures.tuning()
	var cmd := HireStaffCommand.new(s.player_company_id, "Ada", 800)
	assert_true(cmd.validate(s, t).ok)
	var ctx := TickContext.new(s, t)
	cmd.apply(ctx)
	assert_eq(s.staff.size(), 1)
	var st: Staff = s.staff.values()[0]
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


func test_hire_rejected_at_staff_limit() -> void:
	var s := Fixtures.new_state(3)
	var t := Fixtures.tuning()
	for i: int in t.max_staff_default:
		Fixtures.add_staff(s)
	var r := HireStaffCommand.new(s.player_company_id, "X", 800).validate(s, t)
	assert_false(r.ok)
	assert_eq(r.reason_key, &"error.staff_limit")


func test_hire_rejected_for_unknown_company() -> void:
	var s := Fixtures.new_state(3)
	var r := HireStaffCommand.new(999, "X", 800).validate(s, Fixtures.tuning())
	assert_eq(r.reason_key, &"error.company_not_found")


func test_hire_rejected_for_zero_salary() -> void:
	var s := Fixtures.new_state(3)
	var r := HireStaffCommand.new(s.player_company_id, "X", 0).validate(s, Fixtures.tuning())
	assert_eq(r.reason_key, &"error.invalid_salary")
