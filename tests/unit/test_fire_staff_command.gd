extends GutTest


func test_fire_pays_severance_and_lowers_morale() -> void:
	var s := Fixtures.new_state(1)
	var t := Fixtures.tuning()
	var a := Fixtures.add_staff(s, {"salary": 600, "seat_index": 1})
	var b := Fixtures.add_staff(s, {"seat_index": 2, "morale": 70})
	var cmd := FireStaffCommand.new(a)
	assert_true(cmd.validate(s, t).ok)
	var ctx := TickContext.new(s, t)
	cmd.apply(ctx)
	assert_false(s.staff.has(a))
	assert_eq(s.companies[s.player_company_id].money, 19400)
	assert_eq(s.staff[b].morale, 65)
	assert_eq(ctx.events[0]["name"], &"staff_fired")
	assert_eq(ctx.events[1]["name"], &"money_changed")


func test_fire_rejections() -> void:
	var s := Fixtures.new_state(1)
	var t := Fixtures.tuning()
	assert_eq(FireStaffCommand.new(s.owner_staff_id()).validate(s, t).reason_key, &"error.cannot_fire_owner")
	assert_eq(FireStaffCommand.new(999).validate(s, t).reason_key, &"error.staff_not_found")
