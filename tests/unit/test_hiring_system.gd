extends GutTest


func _tick(s: GameState, week: int) -> void:
	s.week = week
	HiringSystem.tick(TickContext.new(s, Fixtures.tuning()))


func test_month_start_adds_candidates() -> void:
	var s := Fixtures.new_state(1)
	var t := Fixtures.tuning()
	_tick(s, 4)
	assert_eq(s.candidates.size(), 3)
	for c: Candidate in s.candidates:
		assert_eq(c.expires_week, 12)
		assert_between(c.level, 0, 2)
		assert_true(c.name.begins_with("staff_name."))
		for k: StringName in c.skills:
			assert_between(c.skills[k], 10, 70)
		var m: int = PeopleRules.market_salary(c.skills, c.level, Fixtures.content(), t)
		assert_between(c.asking_salary, Fixed.mul_bp(m, 9000), Fixed.mul_bp(m, 11500))
	_tick(s, 5)
	assert_eq(s.candidates.size(), 3)


func test_candidates_expire() -> void:
	var s := Fixtures.new_state(1)
	_tick(s, 4)
	_tick(s, 11)
	assert_eq(s.candidates.size(), 3)
	_tick(s, 12)  # week 12 is not a month start in 4-4-5 (12 % 13 == 12)
	assert_eq(s.candidates.size(), 0)


func test_same_seed_same_candidates() -> void:
	var a := Fixtures.new_state(7)
	var b := Fixtures.new_state(7)
	_tick(a, 4)
	_tick(b, 4)
	assert_eq(JSON.stringify(a.to_dict()), JSON.stringify(b.to_dict()))


func _sum(s: GameState) -> int:
	var total: int = 0
	for c: Candidate in s.candidates:
		for k: StringName in c.skills:
			total += c.skills[k]
	return total


func test_recruiter_raises_skills() -> void:
	var a := Fixtures.new_state(3)
	var b := Fixtures.new_state(3)
	b.owner.perks[&"perk_recruiter"] = 1
	b.owner.focus_dev_bp = 0
	_tick(a, 4)
	_tick(b, 4)
	assert_gte(_sum(b), _sum(a))


func test_state_valid_after_hiring_ticks() -> void:
	var s := Fixtures.new_state(2)
	for w: int in range(1, 31):
		_tick(s, w)
	assert_true(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))
