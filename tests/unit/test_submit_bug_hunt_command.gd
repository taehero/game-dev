extends GutTest


func _polish(bugs: int = 30) -> Array:
	var s: GameState = Fixtures.new_state(1)
	var pid: int = Fixtures.add_project(s, {"phase": Project.Phase.POLISH, "bugs": bugs})
	return [s, pid]


func _run(s: GameState, pid: int, caught: int) -> Array[Dictionary]:
	var ctx := TickContext.new(s, Fixtures.tuning())
	SubmitBugHuntCommand.new(pid, caught).apply(ctx)
	return ctx.events


func test_missing_project() -> void:
	var s: GameState = Fixtures.new_state(1)
	assert_eq(SubmitBugHuntCommand.new(999, 1).validate(s, Fixtures.tuning()).reason_key, &"error.project_not_found")


func test_other_company_project() -> void:
	var a: Array = _polish()
	var s: GameState = a[0]
	s.projects[a[1]].company_id = s.player_company_id + 100
	assert_eq(SubmitBugHuntCommand.new(a[1], 1).validate(s, Fixtures.tuning()).reason_key, &"error.project_not_found")


func test_not_polishing() -> void:
	var a: Array = _polish()
	var s: GameState = a[0]
	s.projects[a[1]].phase = Project.Phase.PRODUCTION
	assert_eq(SubmitBugHuntCommand.new(a[1], 1).validate(s, Fixtures.tuning()).reason_key, &"error.project_not_polishing")
	s.projects[a[1]].phase = Project.Phase.POLISH
	s.projects[a[1]].kind = Project.Kind.ENGINE
	assert_eq(SubmitBugHuntCommand.new(a[1], 1).validate(s, Fixtures.tuning()).reason_key, &"error.project_not_polishing")


func test_already_done() -> void:
	var a: Array = _polish()
	var s: GameState = a[0]
	s.projects[a[1]].bug_hunt_done = true
	assert_eq(SubmitBugHuntCommand.new(a[1], 1).validate(s, Fixtures.tuning()).reason_key, &"error.bug_hunt_done")


func test_negative_caught() -> void:
	var a: Array = _polish()
	assert_eq(SubmitBugHuntCommand.new(a[1], -1).validate(a[0], Fixtures.tuning()).reason_key, &"error.invalid_amount")


func test_caps_at_tuning() -> void:
	var a: Array = _polish(30)
	assert_true(SubmitBugHuntCommand.new(a[1], 50).validate(a[0], Fixtures.tuning()).ok)
	_run(a[0], a[1], 50)
	assert_eq(a[0].projects[a[1]].bugs, 30 - Fixtures.tuning().bug_hunt_max_bugs)


func test_caps_at_caught() -> void:
	var a: Array = _polish(30)
	_run(a[0], a[1], 3)
	assert_eq(a[0].projects[a[1]].bugs, 27)


func test_caps_at_bugs() -> void:
	var a: Array = _polish(2)
	_run(a[0], a[1], 5)
	assert_eq(a[0].projects[a[1]].bugs, 0)


func test_zero_caught_marks_done() -> void:
	var a: Array = _polish(30)
	_run(a[0], a[1], 0)
	assert_eq(a[0].projects[a[1]].bugs, 30)
	assert_true(a[0].projects[a[1]].bug_hunt_done)


func test_second_hunt_refused() -> void:
	var a: Array = _polish(30)
	_run(a[0], a[1], 3)
	assert_eq(SubmitBugHuntCommand.new(a[1], 3).validate(a[0], Fixtures.tuning()).reason_key, &"error.bug_hunt_done")


func test_payload_reports_removed() -> void:
	var a: Array = _polish(30)
	var evs: Array[Dictionary] = _run(a[0], a[1], 4)
	assert_eq(evs.size(), 1)
	assert_eq(evs[0]["name"], &"project_changed")
	assert_eq(evs[0]["payload"], {"project_id": a[1], "bugs_removed": 4})
