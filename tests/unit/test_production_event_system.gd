extends GutTest

const KIND_A: StringName = &"pevent_fx_a"
const KIND_B: StringName = &"pevent_fx_b"


func _events() -> Array[Resource]:
	return [Fixtures.pevent(KIND_A, {&"bugs": 1}, {&"hype": 1}), Fixtures.pevent(KIND_B, {&"bugs": 2}, {&"hype": 2})] as Array[Resource]


func before_each() -> void:
	ContentDB.use(Fixtures.content_plus(_events()))


func after_each() -> void:
	ContentDB.use(Fixtures.content())


## Player game in PRODUCTION with one working staff member.
func _setup(seed_value: int = 5) -> Dictionary:
	var s := Fixtures.new_state(seed_value)
	ContentDB.use(Fixtures.content_plus(_events()))
	var pid: int = Fixtures.add_project(s)
	var sid: int = Fixtures.add_worker(s, {"assigned_project_id": pid})
	return {"s": s, "pid": pid, "sid": sid}


func _tuning(chance: int, max_per: int = 2) -> TuningDef:
	var t := TuningDef.new()
	t.production_event_chance_bp = chance
	t.production_event_max_per_project = max_per
	return t


func _copy_rng(r: RandomNumberGenerator) -> RandomNumberGenerator:
	var c := RandomNumberGenerator.new()
	c.seed = r.seed
	c.state = r.state
	return c


func _event_decisions(s: GameState) -> Array[Decision]:
	var out: Array[Decision] = []
	for d: Decision in s.pending_decisions:
		if String(d.kind).begins_with("pevent_"):
			out.append(d)
	return out


func test_no_draw_without_event_content() -> void:
	var s := Fixtures.new_state(5)
	var pid: int = Fixtures.add_project(s)
	Fixtures.add_worker(s, {"assigned_project_id": pid})
	var before: int = s.rng.state
	WorldEventSystem.tick(TickContext.new(s, _tuning(10000)))
	assert_eq(s.rng.state, before)


func test_full_chance_creates_decision() -> void:
	var f: Dictionary = _setup()
	var s: GameState = f["s"]
	var pid: int = f["pid"]
	WorldEventSystem.tick(TickContext.new(s, _tuning(10000)))
	var ds: Array[Decision] = _event_decisions(s)
	assert_eq(ds.size(), 1)
	var d: Decision = ds[0]
	assert_eq(d.related_ids, [pid] as Array[int])
	assert_eq(d.option_keys, ContentDB.active().production_events[d.kind].option_keys)
	assert_eq(d.deadline_week, s.week + 4)
	assert_eq(s.projects[pid].event_ids, [d.kind] as Array[StringName])


func test_draw_order_is_roll_then_pick() -> void:
	var f: Dictionary = _setup()
	var s: GameState = f["s"]
	var copy: RandomNumberGenerator = _copy_rng(s.rng)
	WorldEventSystem.tick(TickContext.new(s, _tuning(10000)))
	assert_true(Fixed.roll_bp(copy, 10000))
	var idx: int = copy.randi_range(0, 1)
	assert_eq(_event_decisions(s)[0].kind, [KIND_A, KIND_B][idx])
	assert_eq(s.rng.state, copy.state)


func test_zero_chance_one_draw_no_decision() -> void:
	var f: Dictionary = _setup()
	var s: GameState = f["s"]
	var copy: RandomNumberGenerator = _copy_rng(s.rng)
	WorldEventSystem.tick(TickContext.new(s, _tuning(0)))
	Fixed.roll_bp(copy, 0)
	assert_eq(_event_decisions(s).size(), 0)
	assert_eq(s.rng.state, copy.state)


func _assert_no_draw(s: GameState, t: TuningDef, label: String) -> void:
	var before: int = s.rng.state
	var n: int = s.pending_decisions.size()
	WorldEventSystem.tick(TickContext.new(s, t))
	assert_eq(s.rng.state, before, "draws: " + label)
	assert_eq(s.pending_decisions.size(), n, "decisions: " + label)


func test_ineligible_projects_draw_nothing() -> void:
	var t: TuningDef = _tuning(10000)
	var s := Fixtures.new_state(5)
	ContentDB.use(Fixtures.content_plus(_events()))
	# POLISH game
	var p1: int = Fixtures.add_project(s, {"phase": Project.Phase.POLISH})
	Fixtures.add_worker(s, {"assigned_project_id": p1})
	_assert_no_draw(s, t, "polish")
	# ENGINE project
	var p2: int = Fixtures.add_project(s, {"kind": Project.Kind.ENGINE})
	Fixtures.add_worker(s, {"assigned_project_id": p2})
	_assert_no_draw(s, t, "engine")
	# other company
	var p3: int = Fixtures.add_project(s, {"company_id": 999})
	Fixtures.add_worker(s, {"assigned_project_id": p3})
	_assert_no_draw(s, t, "other company")
	# no worker
	Fixtures.add_project(s)
	_assert_no_draw(s, t, "no worker")


func test_ineligible_by_event_state_draws_nothing() -> void:
	var t: TuningDef = _tuning(10000)
	# pending event
	var f: Dictionary = _setup()
	var s: GameState = f["s"]
	WorldEventSystem.tick(TickContext.new(s, t))
	assert_eq(_event_decisions(s).size(), 1)
	_assert_no_draw(s, t, "pending")
	# max reached
	var f2: Dictionary = _setup()
	var s2: GameState = f2["s"]
	s2.projects[f2["pid"]].event_ids.assign([KIND_A])
	_assert_no_draw(s2, _tuning(10000, 1), "max")
	# seen every event
	var f3: Dictionary = _setup()
	var s3: GameState = f3["s"]
	s3.projects[f3["pid"]].event_ids.assign([KIND_A, KIND_B])
	_assert_no_draw(s3, _tuning(10000, 5), "seen all")


func test_seen_events_not_repeated() -> void:
	var f: Dictionary = _setup()
	var s: GameState = f["s"]
	s.projects[f["pid"]].event_ids.assign([KIND_A])
	var copy: RandomNumberGenerator = _copy_rng(s.rng)
	WorldEventSystem.tick(TickContext.new(s, _tuning(10000, 5)))
	Fixed.roll_bp(copy, 10000)
	copy.randi_range(0, 0)
	assert_eq(_event_decisions(s)[0].kind, KIND_B)
	assert_eq(s.rng.state, copy.state)


func test_expired_event_removed_without_effect() -> void:
	var f: Dictionary = _setup()
	var s: GameState = f["s"]
	var pid: int = f["pid"]
	var p: Project = s.projects[pid]
	p.event_ids.assign([KIND_A])
	var d := Decision.new()
	d.id = s.alloc_id()
	d.kind = KIND_A
	d.related_ids.assign([pid])
	d.deadline_week = s.week
	d.option_keys.assign(ContentDB.active().production_events[KIND_A].option_keys)
	s.pending_decisions.append(d)
	var staff_morale: int = s.staff[f["sid"]].morale
	var snap: Array = [p.points.duplicate(), p.bugs, p.hype]
	WorldEventSystem.tick(TickContext.new(s, _tuning(10000, 1)))
	assert_eq(s.pending_decisions.size(), 0)
	assert_eq([p.points, p.bugs, p.hype], snap)
	assert_eq(s.staff[f["sid"]].morale, staff_morale)


func test_session_auto_pauses_on_event() -> void:
	var f: Dictionary = _setup()
	var s: GameState = f["s"]
	var g := GameSession.new(s, _tuning(10000))
	g.set_speed(1)
	g.step_once()
	assert_eq(g.speed, 0)
	var ds: Array[Decision] = _event_decisions(s)
	assert_eq(ds.size(), 1)
	var found: bool = false
	for e: Dictionary in g.drain_events():
		if e["name"] == &"decision_required" and e["payload"]["decision_id"] == ds[0].id:
			found = true
	assert_true(found)


func test_pending_event_survives_save_load() -> void:
	var f: Dictionary = _setup()
	var s: GameState = f["s"]
	WorldEventSystem.tick(TickContext.new(s, _tuning(10000)))
	var r: LoadResult = SaveService.deserialize(SaveService.serialize(s))
	assert_true(r.ok)
	assert_true(GameState.validate_dict(Fixtures.json_round_trip(r.state.to_dict())))
	assert_eq(ContentDB.active().missing_refs(r.state), [] as Array[String])
	assert_eq(_event_decisions(r.state).size(), 1)
