extends GutTest

const KIND: StringName = &"pevent_fx_a"


func after_each() -> void:
	ContentDB.use(Fixtures.content())


## Event with the given option_a; option_b is a bugs +1 filler.
func _setup(effects: Dictionary, project: Dictionary = {}) -> Dictionary:
	var s := Fixtures.new_state(5)
	ContentDB.use(Fixtures.content_plus([Fixtures.pevent(KIND, effects, {&"bugs": 1})] as Array[Resource]))
	var pid: int = Fixtures.add_project(s, project)
	var sid: int = Fixtures.add_worker(s, {"assigned_project_id": pid, "morale": 50})
	var d := Decision.new()
	d.id = s.alloc_id()
	d.kind = KIND
	d.related_ids.assign([pid])
	d.deadline_week = s.week + 4
	d.option_keys.assign(ContentDB.active().production_events[KIND].option_keys)
	s.pending_decisions.append(d)
	return {"s": s, "pid": pid, "sid": sid, "did": d.id, "p": s.projects[pid]}


func _run(f: Dictionary, option: int = 0) -> TickContext:
	var s: GameState = f["s"]
	var t := TuningDef.new()
	var cmd := ChooseEventOptionCommand.new(f["did"], option)
	assert_true(cmd.validate(s, t).ok)
	var ctx := TickContext.new(s, t)
	cmd.apply(ctx)
	return ctx


func test_validate_errors() -> void:
	var f: Dictionary = _setup({&"bugs": 1})
	var s: GameState = f["s"]
	var t := TuningDef.new()
	assert_eq(ChooseEventOptionCommand.new(9999, 0).validate(s, t).reason_key, &"error.decision_not_found")
	var other := Decision.new()
	other.id = s.alloc_id()
	other.kind = &"hire_offer"
	s.pending_decisions.append(other)
	assert_eq(ChooseEventOptionCommand.new(other.id, 0).validate(s, t).reason_key, &"error.decision_not_event")
	assert_eq(ChooseEventOptionCommand.new(f["did"], 2).validate(s, t).reason_key, &"error.invalid_option")
	assert_eq(ChooseEventOptionCommand.new(f["did"], -1).validate(s, t).reason_key, &"error.invalid_option")
	s.projects.erase(f["pid"])
	assert_eq(ChooseEventOptionCommand.new(f["did"], 0).validate(s, t).reason_key, &"error.project_not_found")


func test_point_effects_add_and_insert_sorted() -> void:
	var f: Dictionary = _setup({&"design": 50, &"tech": -30}, {"points": {&"tech": 10}})
	_run(f)
	var p: Project = f["p"]
	assert_eq(p.points, {&"design": 50, &"tech": 0})
	assert_eq(p.points.keys(), [&"design", &"tech"])


func test_clamps() -> void:
	var f: Dictionary = _setup({&"bugs": -5, &"hype": 5, &"morale": -10}, {"bugs": 2, "hype": 98})
	f["s"].staff[f["sid"]].morale = 3
	_run(f)
	var p: Project = f["p"]
	assert_eq(p.bugs, 0)
	assert_eq(p.hype, 100)
	assert_eq(f["s"].staff[f["sid"]].morale, 0)


func test_morale_hits_only_assigned_staff() -> void:
	var f: Dictionary = _setup({&"morale": 5})
	var s: GameState = f["s"]
	var other: int = Fixtures.add_staff(s, {"morale": 50})
	var owner_id: int = s.owner_staff_id()
	s.staff[owner_id].assigned_project_id = f["pid"]
	var owner_before: int = s.staff[owner_id].morale
	_run(f)
	assert_eq(s.staff[f["sid"]].morale, 55)
	assert_eq(s.staff[owner_id].morale, mini(100, owner_before + 5))
	assert_eq(s.staff[other].morale, 50)


func test_progress_clamped_within_stage() -> void:
	var f: Dictionary = _setup({&"progress_bp": 2000}, {"stage_progress": 9800, "stage_index": 1})
	_run(f)
	assert_eq(f["p"].stage_progress, 9999)
	assert_eq(f["p"].stage_index, 1)
	var g: Dictionary = _setup({&"progress_bp": -2000}, {"stage_progress": 500})
	_run(g)
	assert_eq(g["p"].stage_progress, 0)


func test_answer_in_polish_ignores_progress() -> void:
	var f: Dictionary = _setup({&"progress_bp": 2000, &"bugs": 3}, {"phase": Project.Phase.POLISH, "stage_progress": 100})
	_run(f)
	assert_eq(f["p"].stage_progress, 100)
	assert_eq(f["p"].bugs, 3)


func test_apply_removes_decision_and_emits_project_changed() -> void:
	var f: Dictionary = _setup({&"bugs": 1})
	var ctx: TickContext = _run(f)
	assert_eq(f["s"].pending_decisions.size(), 0)
	var found: bool = false
	for e: Dictionary in ctx.events:
		if e["name"] == &"project_changed" and e["payload"]["project_id"] == f["pid"]:
			found = true
	assert_true(found)


func test_validate_does_not_mutate() -> void:
	var f: Dictionary = _setup({&"bugs": 1})
	var before: String = StateHash.of(f["s"])
	ChooseEventOptionCommand.new(f["did"], 0).validate(f["s"], TuningDef.new())
	assert_eq(StateHash.of(f["s"]), before)


func test_missing_zero_point_key_not_inserted_and_def_unchanged() -> void:
	var f: Dictionary = _setup({&"art": -10})
	var def: ProductionEventDef = ContentDB.active().production_events[KIND]
	var before: Dictionary = def.option_a.duplicate()
	_run(f)
	assert_false(f["p"].points.has(&"art"))
	assert_eq(def.option_a, before)
