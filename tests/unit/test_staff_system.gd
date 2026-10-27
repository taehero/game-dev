extends GutTest


func _ctx(s: GameState, week: int, t: TuningDef = null) -> TickContext:
	s.week = week
	return TickContext.new(s, t if t != null else Fixtures.tuning())


func _worker_on_crunch(s: GameState, overrides: Dictionary = {}) -> int:
	var pid: int = Fixtures.add_project(s, {"crunch": true})
	overrides["assigned_project_id"] = pid
	return Fixtures.add_worker(s, overrides)


func _asks(s: GameState) -> Array[Decision]:
	var out: Array[Decision] = []
	for d: Decision in s.pending_decisions:
		if AnswerRaiseCommand.KINDS.has(d.kind):
			out.append(d)
	return out


func test_exp_raises_skill_on_hundreds() -> void:
	var s := Fixtures.new_state(1)
	var id: int = Fixtures.add_staff(s, {"exp": {&"tech": 50}, "week_points": {&"tech": 1050}})
	StaffSystem.tick(_ctx(s, 1))
	assert_eq(s.staff[id].exp[&"tech"], 155)
	assert_eq(s.staff[id].skills[&"tech"], 21)
	s.staff[id].skills[&"tech"] = 100
	s.staff[id].week_points = {&"tech": 5000}
	StaffSystem.tick(_ctx(s, 2))
	assert_eq(s.staff[id].skills[&"tech"], 100)


func test_crunch_and_recovery() -> void:
	var s := Fixtures.new_state(1)
	var c: int = _worker_on_crunch(s, {"burnout": 10, "morale": 70})
	var a: int = Fixtures.add_staff(s, {"burnout": 10, "morale": 60})
	var b: int = Fixtures.add_staff(s, {"morale": 80})
	StaffSystem.tick(_ctx(s, 1))
	assert_eq(s.staff[c].burnout, 16)
	assert_eq(s.staff[c].morale, 66)
	assert_eq(s.staff[a].burnout, 8)
	assert_eq(s.staff[a].morale, 61)
	assert_eq(s.staff[b].morale, 79)


func test_crunch_veteran_reduces_owner_burnout() -> void:
	var s := Fixtures.new_state(1)
	s.owner.perks[&"perk_crunch_veteran"] = 1
	var pid: int = Fixtures.add_project(s, {"crunch": true})
	var o: Staff = s.staff[s.owner_staff_id()]
	o.assigned_project_id = pid
	o.burnout = 0
	if GameRules.working_staff(s, pid).is_empty():
		Fixtures.add_equipment(s, {"seat_index": o.seat_index})
	StaffSystem.tick(_ctx(s, 1))
	assert_eq(o.burnout, 4)


func test_raise_ask_on_anniversary() -> void:
	var s := Fixtures.new_state(1)
	var id: int = Fixtures.add_staff(s, {"salary": 300})
	var ctx := _ctx(s, 51)
	StaffSystem.tick(ctx)
	assert_eq(_asks(s).size(), 0)
	ctx = _ctx(s, 52)
	StaffSystem.tick(ctx)
	assert_eq(s.staff[id].asking_raise, 1860)
	assert_eq(_asks(s).size(), 1)
	assert_eq(_asks(s)[0].kind, &"raise_request")
	assert_eq(_asks(s)[0].deadline_week, 56)
	assert_eq(ctx.events[0]["name"], &"raise_requested")
	assert_false(ctx.events[0]["payload"]["promotion"])
	StaffSystem.tick(_ctx(s, 52))
	assert_eq(_asks(s).size(), 1, "one ask at a time")
	var rich: int = Fixtures.add_staff(s, {"salary": 1700})
	StaffSystem.tick(_ctx(s, 104))
	assert_eq(s.staff[rich].asking_raise, 0)


func test_promotion_ask_after_cooldown() -> void:
	var s := Fixtures.new_state(1)
	var id: int = Fixtures.add_staff(s, {"salary": 5000, "skills": {&"design": 40, &"tech": 20, &"art": 20, &"audio": 20},
		"exp": {&"design": 2000}})
	StaffSystem.tick(_ctx(s, 25))
	assert_eq(_asks(s).size(), 0)
	StaffSystem.tick(_ctx(s, 26))
	assert_eq(s.staff[id].asking_raise, 2860)
	assert_eq(_asks(s)[0].kind, &"promotion_request")


func test_owner_never_asks_and_self_promotes() -> void:
	var s := Fixtures.new_state(1)
	var o: Staff = s.staff[s.owner_staff_id()]
	o.salary = 1
	o.skills[&"design"] = 50
	o.exp = {&"design": 2500}
	StaffSystem.tick(_ctx(s, 52))
	assert_eq(_asks(s).size(), 0)
	assert_eq(o.level, Staff.Level.MID)


func test_unanswered_ask_expires_as_refused() -> void:
	var s := Fixtures.new_state(1)
	var id: int = Fixtures.add_staff(s, {"salary": 300, "morale": 70})
	StaffSystem.tick(_ctx(s, 52))
	StaffSystem.tick(_ctx(s, 55))
	assert_eq(_asks(s).size(), 1)
	StaffSystem.tick(_ctx(s, 56))
	assert_eq(s.staff[id].raise_refusals, 1)
	assert_eq(s.staff[id].morale, 56, "70 - 15 + 1 recovery")
	assert_eq(s.staff[id].asking_raise, 0)
	assert_eq(_asks(s).size(), 0)


func test_resignation_rolls() -> void:
	var s := Fixtures.new_state(1)
	var t := Fixtures.tuning()
	t.resign_base_chance_bp = 10000
	var id: int = Fixtures.add_staff(s, {"burnout": 90})
	var o: Staff = s.staff[s.owner_staff_id()]
	o.burnout = 100
	var ctx := _ctx(s, 1, t)
	StaffSystem.tick(ctx)
	assert_false(s.staff.has(id))
	assert_true(s.staff.has(s.owner_staff_id()))
	assert_eq(ctx.events[ctx.events.size() - 1]["name"], &"staff_resigned")
	t.resign_base_chance_bp = 5000
	var seed_no: int = -1
	for sd: int in range(1, 50):
		var sp := Fixtures.new_state(sd)
		var pid: int = Fixtures.add_staff(sp, {"morale": 10})
		StaffSystem.tick(_ctx(sp, 1, t))
		if sp.staff.has(pid):
			seed_no = sd
			break
	assert_gt(seed_no, 0, "a seed exists where 50% roll does not resign")
	var s2 := Fixtures.new_state(seed_no)
	var id2: int = Fixtures.add_staff(s2, {"morale": 10, "raise_refusals": 2})
	StaffSystem.tick(_ctx(s2, 1, t))
	assert_false(s2.staff.has(id2), "double chance (100%) resigns where single did not")


func test_resign_chance_burnout_term() -> void:
	var t := Fixtures.tuning()
	t.resign_base_chance_bp = 0
	t.resign_chance_per_burnout_bp = 10000
	var s := Fixtures.new_state(1)
	var id: int = Fixtures.add_staff(s, {"burnout": 85, "morale": 70})
	StaffSystem.tick(_ctx(s, 1, t))
	assert_false(s.staff.has(id))
	var s2 := Fixtures.new_state(1)
	t.resign_chance_per_burnout_bp = 0
	var id2: int = Fixtures.add_staff(s2, {"burnout": 85, "morale": 70})
	StaffSystem.tick(_ctx(s2, 1, t))
	assert_true(s2.staff.has(id2))


func test_unanswered_promotion_applies_promotion_refuse_morale() -> void:
	var s := Fixtures.new_state(1)
	var id: int = Fixtures.add_staff(s, {"salary": 5000, "morale": 70, "skills": {&"design": 40, &"tech": 20, &"art": 20, &"audio": 20},
		"exp": {&"design": 2000}})
	StaffSystem.tick(_ctx(s, 26))
	assert_eq(_asks(s)[0].kind, &"promotion_request")
	StaffSystem.tick(_ctx(s, 30))
	assert_eq(s.staff[id].raise_refusals, 1)
	assert_eq(s.staff[id].morale, 61, "70 - 10 + 1 recovery")
	assert_eq(_asks(s).size(), 0)


func test_no_rng_without_eligible_staff() -> void:
	var s := Fixtures.new_state(1)
	Fixtures.add_staff(s, {"burnout": 10, "morale": 70})
	var before: int = s.rng.state
	StaffSystem.tick(_ctx(s, 1))
	assert_eq(s.rng.state, before)
