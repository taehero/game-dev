extends GutTest


func test_set_and_reject() -> void:
	var s: GameState = Fixtures.new_state(1)
	var t: TuningDef = Fixtures.tuning()
	var pid: int = Fixtures.add_project(s)
	var good: Array[int] = [5000, 3000, 2000, 3000, 3000, 4000, 4000, 3000, 3000]
	var cmd := SetSlidersCommand.new(pid, good)
	assert_true(cmd.validate(s, t).ok)
	cmd.apply(TickContext.new(s, t))
	assert_eq(s.projects[pid].focus, good)
	var bad: Array[int] = [5000, 3000, 2001, 3000, 3000, 4000, 4000, 3000, 3000]
	assert_eq(SetSlidersCommand.new(pid, bad).validate(s, t).reason_key, &"error.invalid_sliders")
	s.projects[pid].stage_index = 1
	var past: Array[int] = [4000, 3000, 3000, 3000, 3000, 4000, 4000, 3000, 3000]
	assert_eq(SetSlidersCommand.new(pid, past).validate(s, t).reason_key, &"error.past_stage_locked")
	s.projects[pid].phase = Project.Phase.POLISH
	assert_eq(SetSlidersCommand.new(pid, good).validate(s, t).reason_key, &"error.project_not_in_production")


func test_missing_project_and_wrong_count() -> void:
	var s: GameState = Fixtures.new_state(1)
	var t: TuningDef = Fixtures.tuning()
	var good: Array[int] = [5000, 3000, 2000, 3000, 3000, 4000, 4000, 3000, 3000]
	assert_eq(SetSlidersCommand.new(999, good).validate(s, t).reason_key, &"error.project_not_found")
	var pid: int = Fixtures.add_project(s)
	var short: Array[int] = [10000, 0, 0]
	assert_eq(SetSlidersCommand.new(pid, short).validate(s, t).reason_key, &"error.invalid_sliders")
	var neg: Array[int] = [11000, -1000, 0, 3000, 3000, 4000, 4000, 3000, 3000]
	assert_eq(SetSlidersCommand.new(pid, neg).validate(s, t).reason_key, &"error.invalid_sliders")
	s.projects[pid].kind = Project.Kind.ENGINE
	assert_eq(SetSlidersCommand.new(pid, good).validate(s, t).reason_key, &"error.project_not_in_production")
