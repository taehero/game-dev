extends GutTest


func _cand(s: GameState) -> int:
	var c := Candidate.new()
	c.id = s.alloc_id()
	c.name = "staff_name.03"
	c.skills = {&"art": 30, &"audio": 20, &"design": 25, &"tech": 40}
	c.asking_salary = 777
	c.level = 1
	s.candidates.append(c)
	return c.id


func test_hire_candidate_seats_and_removes() -> void:
	var s := Fixtures.new_state(1)
	var t := Fixtures.tuning()
	s.week = 9
	var cid := _cand(s)
	var cmd := HireCandidateCommand.new(s.player_company_id, cid)
	assert_true(cmd.validate(s, t).ok)
	var ctx := TickContext.new(s, t)
	cmd.apply(ctx)
	assert_eq(s.candidates.size(), 0)
	var hired: Staff = s.staff[s.staff.keys().max()]
	assert_eq(hired.salary, 777)
	assert_eq(hired.level, Staff.Level.MID)
	assert_eq(hired.name, "staff_name.03")
	assert_eq(hired.hired_week, 9)
	assert_eq(hired.last_raise_week, 9)
	assert_eq(hired.skills[&"tech"], 40)
	assert_eq(hired.seat_index, 1)
	assert_eq(ctx.events[0]["name"], &"staff_hired")


func test_hire_rejections() -> void:
	var s := Fixtures.new_state(1)
	var t := Fixtures.tuning()
	var cid := _cand(s)
	assert_eq(HireCandidateCommand.new(99, cid).validate(s, t).reason_key, &"error.company_not_found")
	assert_eq(HireCandidateCommand.new(s.player_company_id, 999).validate(s, t).reason_key, &"error.candidate_not_found")
	var seats: int = ContentDB.active().offices[s.companies[s.player_company_id].office_id].seats
	for i: int in seats - 1:
		Fixtures.add_worker(s)
	assert_eq(HireCandidateCommand.new(s.player_company_id, cid).validate(s, t).reason_key, &"error.no_free_seat")
