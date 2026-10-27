extends GutTest


func _setup() -> Array:
	var s := Fixtures.new_state(1)
	for sid: int in s.staff:
		s.staff[sid].seat_index = -1
	var w: int = Fixtures.add_worker(s)
	var pid: int = Fixtures.add_project(s, {"phase": Project.Phase.LIVE, "sales_base_units": 1000})
	var p: Project = s.projects[pid]
	p.config[&"genre"] = &"genre_fx_action"
	p.features = [&"feat_a"]
	return [s, pid, w]


func _ctx(s: GameState) -> TickContext:
	return TickContext.new(s, Fixtures.tuning())


func _dlc(s: GameState, parent: int) -> Project:
	var cmd := StartDLCCommand.new(parent, "Add-on")
	assert_true(cmd.validate(s, Fixtures.tuning()).ok)
	cmd.apply(_ctx(s))
	for id: int in s.projects:
		if s.projects[id].parent_id == parent:
			return s.projects[id]
	return null


func test_start_dlc_creates_linked_project() -> void:
	var r := _setup()
	var s: GameState = r[0]
	var parent: Project = s.projects[r[1]]
	var d: Project = _dlc(s, r[1])
	assert_not_null(d)
	assert_eq(d.parent_id, r[1])
	assert_eq(d.size_id, &"size_dlc")
	assert_eq(d.kind, Project.Kind.GAME)
	assert_eq(d.phase, Project.Phase.PRODUCTION)
	assert_eq(d.config, parent.config)
	assert_eq(d.engine_id, parent.engine_id)
	assert_eq(d.features, parent.features)
	assert_eq(s.staff[r[2]].assigned_project_id, d.id)
	assert_eq(parent.dlc_count, 1)


func test_rejects_parent_not_live() -> void:
	var r := _setup()
	var s: GameState = r[0]
	s.projects[r[1]].phase = Project.Phase.POLISH
	assert_eq(StartDLCCommand.new(r[1], "x").validate(s, Fixtures.tuning()).reason_key, &"error.project_not_live")


func test_rejects_dlc_of_dlc() -> void:
	var r := _setup()
	var s: GameState = r[0]
	s.projects[r[1]].parent_id = 99
	assert_eq(StartDLCCommand.new(r[1], "x").validate(s, Fixtures.tuning()).reason_key, &"error.dlc_of_dlc")


func test_rejects_second_dlc_in_progress() -> void:
	var r := _setup()
	var s: GameState = r[0]
	var d: Project = _dlc(s, r[1])
	Fixtures.add_worker(s)
	assert_eq(StartDLCCommand.new(r[1], "x").validate(s, Fixtures.tuning()).reason_key, &"error.dlc_in_progress")
	d.phase = Project.Phase.RELEASED
	assert_true(StartDLCCommand.new(r[1], "x").validate(s, Fixtures.tuning()).ok)


func test_start_project_refuses_dlc_size() -> void:
	var s := Fixtures.new_state(1)
	var cmd := StartProjectCommand.game(1, "g", &"size_dlc", &"platform_fx_micro", &"topic_fx_space", &"genre_fx_action", -1, &"", [] as Array[StringName])
	assert_eq(cmd.validate(s, Fixtures.tuning()).reason_key, &"error.size_dlc_only")


func _launch(parent_mod: bool, parent_phase: Project.Phase, units: Array[int]) -> Project:
	var r := _setup()
	var s: GameState = r[0]
	var parent: Project = s.projects[r[1]]
	parent.phase = parent_phase
	parent.mod_tools = parent_mod
	var d: Project
	var did: int = Fixtures.add_project(s, {"phase": Project.Phase.LIVE})
	d = s.projects[did]
	d.parent_id = r[1]
	d.weekly_units = units
	LiveOpsSystem.tick(_ctx(s))
	return parent


func test_dlc_launch_extends_parent_tail() -> void:
	assert_eq(_launch(false, Project.Phase.LIVE, [50] as Array[int]).sales_base_units, 1500)


func test_mod_tools_reduce_dlc_uplift() -> void:
	assert_eq(_launch(true, Project.Phase.LIVE, [50] as Array[int]).sales_base_units, 1300)


func test_no_uplift_for_retired_parent() -> void:
	assert_eq(_launch(false, Project.Phase.RETIRED, [50] as Array[int]).sales_base_units, 1000)


func test_uplift_only_on_launch_week() -> void:
	assert_eq(_launch(false, Project.Phase.LIVE, [50, 40] as Array[int]).sales_base_units, 1000)
