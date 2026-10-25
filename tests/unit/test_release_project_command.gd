extends GutTest


func test_release_creates_four_reviews_and_frees_staff() -> void:
	var s := Fixtures.new_state(1)
	var t := Fixtures.tuning()
	var pid := Fixtures.add_project(s, {"phase": Project.Phase.POLISH, "points": {&"design": 3000, &"tech": 3000}})
	s.staff[s.owner_staff_id()].assigned_project_id = pid
	var cmd := ReleaseProjectCommand.new(pid)
	assert_true(cmd.validate(s, t).ok)
	var ctx := TickContext.new(s, t)
	cmd.apply(ctx)
	var p: Project = s.projects[pid]
	assert_eq(p.phase, Project.Phase.RELEASED)
	assert_eq(p.release_week, 0)
	assert_eq(p.review_results.size(), 4)
	var ids: Array[StringName] = []
	for r: ReviewResult in p.review_results:
		ids.append(r.outlet_id)
	assert_eq(ids, [&"outlet_fx_a", &"outlet_fx_b", &"outlet_fx_c", &"outlet_fx_d"] as Array[StringName])
	assert_between(p.user_score, 10, 100)
	assert_eq(s.staff[s.owner_staff_id()].assigned_project_id, -1)
	var names: Array[StringName] = []
	for e: Dictionary in ctx.events:
		names.append(e["name"])
	assert_has(names, &"review_published")
	assert_has(names, &"project_phase_changed")
	assert_true(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))


func test_release_allowed_after_platform_retires() -> void:
	var s := Fixtures.new_state(1)
	s.week = 400
	var pid := Fixtures.add_project(s, {"phase": Project.Phase.POLISH})
	assert_true(ReleaseProjectCommand.new(pid).validate(s, Fixtures.tuning()).ok)


func test_release_rejected_before_polish() -> void:
	var s := Fixtures.new_state(1)
	var pid := Fixtures.add_project(s)
	assert_eq(ReleaseProjectCommand.new(pid).validate(s, Fixtures.tuning()).reason_key, &"error.project_not_ready")
	assert_eq(ReleaseProjectCommand.new(999).validate(s, Fixtures.tuning()).reason_key, &"error.project_not_found")


func test_release_rejected_for_engine_project() -> void:
	var s := Fixtures.new_state(1)
	var pid := Fixtures.add_project(s, {"phase": Project.Phase.POLISH, "kind": Project.Kind.ENGINE})
	assert_eq(ReleaseProjectCommand.new(pid).validate(s, Fixtures.tuning()).reason_key, &"error.project_not_ready")
