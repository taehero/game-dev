extends GutTest

var s: GameState
var t: TuningDef
var pid: int


func before_each() -> void:
	s = Fixtures.new_state(1)
	t = Fixtures.tuning()
	pid = Fixtures.add_project(s)
	s.staff[s.owner_staff_id()].assigned_project_id = pid


func _tick() -> TickContext:
	var ctx := TickContext.new(s, t)
	ProductionSystem.tick(ctx)
	return ctx


func test_stage_one_points_follow_sliders() -> void:
	_tick()
	# stage 1 sliders: Code 3334 -> tech, Design 3333 + Story 3333 -> design
	var tech: int = Fixed.mul_bp(Fixed.mul_bp(Fixed.mul_bp(Fixed.mul_bp(300, 3334), 10000), 10200), 10000)
	var des: int = 2 * Fixed.mul_bp(Fixed.mul_bp(Fixed.mul_bp(Fixed.mul_bp(300, 3333), 10000), 10200), 10000)
	assert_eq(s.projects[pid].points[&"tech"], tech)
	assert_eq(s.projects[pid].points[&"design"], des)
	assert_eq(s.staff[s.owner_staff_id()].week_points[&"design"], des)


func test_six_weeks_finish_stage_one() -> void:
	for i: int in 5:
		_tick()
	assert_eq(s.projects[pid].stage_index, 0)
	var ctx := _tick()
	assert_eq(s.projects[pid].stage_index, 1)
	assert_true(ctx.events.any(func(e: Dictionary) -> bool: return e["name"] == &"project_stage_changed"))


func test_game_moves_to_polish_after_18_weeks_and_polish_fixes_bugs() -> void:
	for i: int in 18:
		_tick()
	assert_eq(s.projects[pid].phase, Project.Phase.POLISH)
	s.projects[pid].bugs = 10
	var before: Dictionary = s.projects[pid].points.duplicate()
	_tick()
	assert_eq(s.projects[pid].bugs, 7)
	assert_eq(s.projects[pid].points, before)


func test_polish_draws_no_rng() -> void:
	for i: int in 18:
		_tick()
	var before: int = s.rng.state
	_tick()
	assert_eq(s.rng.state, before)


func test_crunch_speeds_progress() -> void:
	s.projects[pid].crunch = true
	_tick()
	assert_eq(s.projects[pid].stage_progress, Fixed.mul_bp(1667, 15000))


func test_bugs_two_per_week_plus_one_roll() -> void:
	_tick()
	assert_between(s.projects[pid].bugs, 2, 3)


func test_no_workers_no_progress_no_events() -> void:
	Removal.remove_equipment(s, GameRules.equipment_at_seat(s, 1, 0))
	var ctx := _tick()
	assert_eq(s.projects[pid].stage_progress, 0)
	assert_eq(ctx.events.size(), 0)
	assert_eq(s.staff[s.owner_staff_id()].week_points, {})


func test_engine_project_builds_engine() -> void:
	var eid: int = Fixtures.add_project(s, {"kind": Project.Kind.ENGINE, "size_id": &"",
		"focus": GameRules.ENGINE_FOCUS, "features": [&"feature_fx_save", &"feature_fx_scroll"] as Array[StringName]})
	s.staff[s.owner_staff_id()].assigned_project_id = eid
	s.projects[pid].phase = Project.Phase.LIVE
	for i: int in 6:
		_tick()
	assert_eq(s.projects[eid].phase, Project.Phase.RETIRED)
	assert_eq(s.engines.size(), 1)
	var e: GameEngine = s.engines.values()[0]
	assert_eq(e.tech_cap, 45)  # 30 + 5 + 10
	assert_eq(s.staff[s.owner_staff_id()].assigned_project_id, -1)
	assert_true(s.projects[eid].points[&"tech"] > 0)
	assert_eq(s.projects[eid].points.keys(), [&"tech"])


func test_same_seed_same_bugs() -> void:
	var a: GameState = Fixtures.new_state(9)
	var b: GameState = Fixtures.new_state(9)
	for st: GameState in [a, b]:
		var p: int = Fixtures.add_project(st)
		st.staff[st.owner_staff_id()].assigned_project_id = p
		for i: int in 18:
			ProductionSystem.tick(TickContext.new(st, t))
	assert_eq(StateHash.of(a), StateHash.of(b))


func test_morale_bp_bounds() -> void:
	assert_eq(ProductionSystem.morale_bp(70, t), 10200)
	assert_eq(ProductionSystem.morale_bp(0, t), t.morale_factor_min_bp)
	assert_eq(ProductionSystem.morale_bp(100, t), t.morale_factor_max_bp)


func test_engine_age_bp_built_engine_uses_weeks_per_year() -> void:
	var eid: int = Fixtures.add_engine(s, {"built_week": 0})
	s.projects[pid].engine_id = eid
	s.week = 2 * t.weeks_per_year + 5
	assert_eq(ProductionSystem.engine_age_bp(s, Fixtures.content(), s.projects[pid], t), Fixed.ONE_BP + 2 * t.engine_age_bug_bp_per_year)


func test_engine_age_bp_licensed_engine_uses_year_from() -> void:
	s.projects[pid].engine_id = -1
	s.projects[pid].config[&"engine"] = &"lic_engine_homebrew"
	var lic: LicensedEngineDef = Fixtures.content().licensed_engines[&"lic_engine_homebrew"]
	var years: int = Calendar.year(s.week, t) - lic.year_from
	assert_eq(ProductionSystem.engine_age_bp(s, Fixtures.content(), s.projects[pid], t), Fixed.ONE_BP + years * t.engine_age_bug_bp_per_year)
