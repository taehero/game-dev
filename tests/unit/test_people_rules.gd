extends GutTest

var _t: TuningDef


func before_each() -> void:
	ContentDB.use(Fixtures.content())
	_t = Fixtures.tuning()


func _skills(v: int) -> Dictionary[StringName, int]:
	var d: Dictionary[StringName, int] = {}
	for k: StringName in [&"audio", &"art", &"design", &"tech"]:
		d[k] = v
	return d


func test_market_salary() -> void:
	assert_eq(PeopleRules.market_salary(_skills(20), 0, Fixtures.content(), _t), 680)
	assert_eq(PeopleRules.market_salary(_skills(20), 1, Fixtures.content(), _t), 884)


func test_promotion_eligible() -> void:
	var s := Staff.new()
	s.skills = {&"design": 40, &"tech": 10}
	s.exp = {&"design": 1500, &"tech": 500}
	assert_true(PeopleRules.promotion_eligible(s, Fixtures.content()))
	s.exp[&"tech"] = 499
	assert_false(PeopleRules.promotion_eligible(s, Fixtures.content()))
	s.exp[&"tech"] = 500
	s.level = Staff.Level.LEAD
	assert_false(PeopleRules.promotion_eligible(s, Fixtures.content()))


func test_effect_bp_scaling() -> void:
	var state: GameState = Fixtures.new_state(1)
	var c: ContentDB = Fixtures.content()
	state.owner.perks = {&"perk_engine_architect": 2, &"perk_accountant": 1, &"perk_unknown": 3}
	for f: int in [10000, 0, 4000]:
		state.owner.focus_dev_bp = f
		assert_eq(PeopleRules.effect_bp(state, c, &"engine_speed_bp"), 3000)
	state.owner.focus_dev_bp = 10000
	assert_eq(PeopleRules.effect_bp(state, c, &"loan_rate_bp"), 0)
	state.owner.focus_dev_bp = 0
	assert_eq(PeopleRules.effect_bp(state, c, &"loan_rate_bp"), -1500)
	state.owner.focus_dev_bp = 4000
	assert_eq(PeopleRules.effect_bp(state, c, &"loan_rate_bp"), -900)


func test_owner_point_bp() -> void:
	var state: GameState = Fixtures.new_state(1)
	state.owner.focus_dev_bp = 5000
	assert_eq(PeopleRules.owner_point_bp(state, state.staff[state.owner_staff_id()]), 5000)
	var other: int = Fixtures.add_staff(state)
	assert_eq(PeopleRules.owner_point_bp(state, state.staff[other]), 10000)


func test_progress_bp() -> void:
	var state: GameState = Fixtures.new_state(1)
	state.owner.perks = {&"perk_engine_architect": 1}
	var eng: int = Fixtures.add_project(state, {"kind": Project.Kind.ENGINE})
	var game: int = Fixtures.add_project(state)
	var c: ContentDB = Fixtures.content()
	assert_eq(PeopleRules.progress_bp(state, c, state.projects[eng]), 11500)
	assert_eq(PeopleRules.progress_bp(state, c, state.projects[game]), 10000)


func test_chemistry_lead_and_leader() -> void:
	var state: GameState = Fixtures.new_state(1)
	var c: ContentDB = Fixtures.content()
	var pid: int = Fixtures.add_project(state)
	var a: int = Fixtures.add_worker(state, {"assigned_project_id": pid, "level": Staff.Level.LEAD})
	var b: int = Fixtures.add_worker(state, {"assigned_project_id": pid})
	assert_eq(PeopleRules.chemistry_bp(state, c, _t, pid, b), 10500)
	assert_eq(PeopleRules.chemistry_bp(state, c, _t, pid, a), 10000)
	state.owner.perks = {&"perk_leader": 2}
	state.owner.focus_dev_bp = 5000
	assert_eq(PeopleRules.chemistry_bp(state, c, _t, pid, b), 11000)
	assert_eq(PeopleRules.chemistry_bp(state, c, _t, pid, state.owner_staff_id()), 10500)


func test_equipment_age_and_availability() -> void:
	var c: ContentDB = Fixtures.content()
	var micro: EquipmentDef = c.equipment[&"equipment_micro_1980"]
	assert_eq(PeopleRules.equipment_speed_bp(micro, 0, _t), 10000)
	assert_eq(PeopleRules.equipment_bug_bp(micro, 0, _t), 10000)
	assert_eq(PeopleRules.equipment_speed_bp(micro, 312, _t), 8000)
	assert_eq(PeopleRules.equipment_bug_bp(micro, 312, _t), 13000)
	assert_eq(PeopleRules.equipment_speed_bp(null, 312, _t), 10000)
	var fut: EquipmentDef = c.equipment[&"equipment_fx_future"]
	assert_false(PeopleRules.equipment_available(fut, 0, _t))
	assert_true(PeopleRules.equipment_available(fut, 520, _t))


func test_morale_baseline_with_leader() -> void:
	var state: GameState = Fixtures.new_state(1)
	state.owner.perks = {&"perk_leader": 1}
	state.owner.focus_dev_bp = 0
	assert_eq(PeopleRules.morale_baseline(state, Fixtures.content(), _t), 75)


func test_validate_reports_bad_perk() -> void:
	var db := ContentDB.new()
	var p := PerkDef.new()
	p.id = &"perk_bad"
	p.path = &"DEV"
	p.max_rank = 1
	p.effects_bp_per_rank = {&"nope": 100}
	db.add(p)
	assert_eq(db.validate().size(), 1)
