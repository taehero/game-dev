class_name Fixtures
extends RefCounted
## Shared test helpers. Not a test file.


static func json_round_trip(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d, "", true, true))


## Fresh defaults, so tests do not depend on edits to data/tuning.tres.
static func tuning() -> TuningDef:
	return TuningDef.new()


static func new_state(p_seed: int) -> GameState:
	ContentDB.use(content())
	return GameState.new_game(p_seed, "Test Studio", tuning())


static func add_staff(state: GameState, overrides: Dictionary = {}) -> int:
	var s := Staff.new()
	s.id = state.alloc_id()
	s.company_id = state.player_company_id
	s.name = "Staff %d" % s.id
	s.salary = 500
	for skill: StringName in [&"design", &"tech", &"art", &"audio"]:
		s.skills[skill] = 20
	for k: Variant in overrides:
		_apply(s, String(k), overrides[k])
	state.staff[s.id] = s
	return s.id


static func add_equipment(state: GameState, overrides: Dictionary = {}) -> int:
	var e := Equipment.new()
	e.id = state.alloc_id()
	e.company_id = state.player_company_id
	e.def_id = &"equipment_micro_1980"
	e.seat_index = -1
	for k: Variant in overrides:
		_apply(e, String(k), overrides[k])
	state.equipment[e.id] = e
	return e.id


static func add_engine(state: GameState, overrides: Dictionary = {}) -> int:
	var g := GameEngine.new()
	g.id = state.alloc_id()
	g.company_id = state.player_company_id
	g.name = "Engine %d" % g.id
	g.features = [&"feature_fx_save"]
	g.tech_cap = 35
	g.source = GameEngine.Source.BUILT
	for k: Variant in overrides:
		_apply(g, String(k), overrides[k])
	state.engines[g.id] = g
	return g.id


## Staff in the lowest free player seat plus equipment at that seat, then overrides.
## Does not check office seats; tests needing more than 2 workers set office_id = &"office_small".
static func add_worker(state: GameState, overrides: Dictionary = {}) -> int:
	var used: Dictionary = {}
	for sid: int in state.staff_of(state.player_company_id):
		used[state.staff[sid].seat_index] = true
	for eid: int in state.sorted_ids(state.equipment):
		if state.equipment[eid].company_id == state.player_company_id:
			used[state.equipment[eid].seat_index] = true
	var seat: int = 0
	while used.has(seat):
		seat += 1
	if overrides.has("seat_index"):
		seat = int(overrides["seat_index"])
	var staff_overrides: Dictionary = overrides.duplicate()
	staff_overrides["seat_index"] = seat
	var id: int = add_staff(state, staff_overrides)
	add_equipment(state, {"seat_index": seat})
	return id


static func add_project(state: GameState, overrides: Dictionary = {}) -> int:
	var p := Project.new()
	p.id = state.alloc_id()
	p.company_id = state.player_company_id
	p.title = "Project %d" % p.id
	p.deadline_week = state.week + 24
	p.kind = Project.Kind.GAME
	p.size_id = &"size_small"
	p.config[&"engine"] = &"lic_engine_homebrew"
	p.config[&"genre"] = &"genre_fx_action"
	p.config[&"platform"] = &"platform_fx_micro"
	p.config[&"topic"] = &"topic_fx_space"
	p.phase = Project.Phase.PRODUCTION
	for k: Variant in overrides:
		_apply(p, String(k), overrides[k])
	state.projects[p.id] = p
	return p.id


## Arrays and Dictionaries are assigned into the existing typed container so tests can pass untyped literals.
static func _apply(obj: Object, field: String, value: Variant) -> void:
	var current: Variant = obj.get(field)
	if current is Array and value is Array:
		(current as Array).assign(value)
	elif current is Dictionary and value is Dictionary:
		(current as Dictionary).assign(value)
	else:
		obj.set(field, value)


# --- fixture content (in-memory, never reads data/) ---

static var _content: ContentDB = null
static var _real_content: ContentDB = null


static func content() -> ContentDB:
	if _content != null:
		return _content
	var db := ContentDB.new()
	var defs: Array[Resource] = [
		_office(&"office_garage", 2, 0, 20, 0, [Vector2i(2, 2), Vector2i(5, 2)] as Array[Vector2i]),
		_office(&"office_small", 5, 400, 40, 1500, [] as Array[Vector2i]),
		_equip(&"equipment_micro_1980", 1, 1500, 60, 10, 10000, 10000, 1985),
		_equip(&"equipment_fx_fast", 2, 3000, 0, 0, 15000, 5000, 1990),
		_level(&"level_junior", 0, 0, 0, 10000, 10000),
		_level(&"level_mid", 1, 40, 2000, 13000, 11500),
		_level(&"level_senior", 2, 60, 6000, 17000, 13000),
		_level(&"level_lead", 3, 75, 12000, 22000, 14500),
		_size(&"size_small", 18, 1, 10000, 100, 12, 9000),
		_size(&"size_medium", 30, 2, 18000, 180, 20, 24000),
		_platform(&"platform_fx_micro", &"micro", -52, 400, 0, 0, 40, [40000, 52000, 64000, 70000] as Array[int], {&"genre_fx_action": 12000}),
		_platform(&"platform_fx_console", &"console", 20, 60, 3000, 8, 60, [0, 13000, 26000] as Array[int], {}),
		_genre(&"genre_fx_action", [5000, 3000, 2000, 3000, 3000, 4000, 4000, 3000, 3000] as Array[int]),
		_genre(&"genre_fx_adventure", [2000, 4000, 4000, 5000, 3000, 2000, 4000, 3000, 3000] as Array[int]),
		_topic(&"topic_fx_space", {&"genre_fx_action": 15000, &"genre_fx_adventure": 8000}),
		_topic(&"topic_fx_ghost", {&"genre_fx_adventure": 14000}),
		_feature(&"feature_fx_save", &"", 5, 2),
		_feature(&"feature_fx_scroll", &"research_fx_scroll", 10, 4),
		_research(&"research_fx_scroll", 50, [] as Array[StringName], [&"feature_fx_scroll"] as Array[StringName]),
		_research(&"research_fx_adventure", 80, [&"research_fx_scroll"] as Array[StringName], [&"genre_fx_adventure", &"topic_fx_ghost"] as Array[StringName]),
		_research(&"research_fx_medium", 100, [] as Array[StringName], [&"size_medium"] as Array[StringName]),
		_lic_engine(&"lic_engine_homebrew", 1975, 1999, 0, 0, 40, [&"feature_fx_save"] as Array[StringName]),
		_lic_engine(&"lic_engine_fx_pro", 1980, 1989, 5000, 1000, 60, [&"feature_fx_save", &"feature_fx_scroll"] as Array[StringName]),
		_outlet(&"outlet_fx_a", _all_dims(1000), 0),
		_outlet(&"outlet_fx_b", {&"gameplay": 3000, &"tech": 1000, &"graphics": 1000, &"bugs": 1000}, 2),
		_outlet(&"outlet_fx_c", {&"graphics": 3000, &"audio": 2000, &"story": 1000}, -2),
		_outlet(&"outlet_fx_d", {&"innovation": 2000, &"market_fit": 2000, &"value": 2000}, 0),
	]
	for dim: StringName in ReviewOutletDef.DIMENSIONS:
		defs.append(_template(StringName("review_tpl_fx_%s_strong" % dim), dim, true, 70, StringName("review.strong.%s" % dim)))
		defs.append(_template(StringName("review_tpl_fx_%s_weak" % dim), dim, false, 40, StringName("review.weak.%s" % dim)))
	defs.append(_template(&"review_tpl_fx_generic_strong", &"generic", true, 0, &"review.strong.generic"))
	defs.append(_template(&"review_tpl_fx_generic_weak", &"generic", false, 100, &"review.weak.generic"))
	for d: Resource in defs:
		db.add(d)
	_content = db
	return db


## Real data/ content, loaded once and installed. Tests using it restore content() in after_all.
static func use_real_content() -> void:
	if _real_content == null:
		_real_content = ContentDB.load_dir()
	ContentDB.use(_real_content)


static func _all_dims(w: int) -> Dictionary:
	var d: Dictionary = {}
	for dim: StringName in ReviewOutletDef.DIMENSIONS:
		d[dim] = w
	return d


static func _office(id: StringName, seats: int, rent: int, elec: int, moving: int, desks: Array[Vector2i]) -> OfficeDef:
	var d := OfficeDef.new()
	d.id = id
	d.name_key = StringName("fx.%s" % id)
	d.seats = seats
	d.rent_per_month = rent
	d.electricity_base = elec
	d.moving_cost = moving
	d.desk_positions = desks
	return d


static func _equip(id: StringName, tier: int, price: int, lease: int, power: int, speed: int, bug: int, until: int) -> EquipmentDef:
	var d := EquipmentDef.new()
	d.id = id
	d.name_key = StringName("fx.%s" % id)
	d.tier = tier
	d.price = price
	d.lease_per_month = lease
	d.power_per_month = power
	d.speed_bp = speed
	d.bug_bp = bug
	d.recommended_until_year = until
	return d


static func _level(id: StringName, level: int, best: int, exp: int, salary: int, output: int) -> LevelDef:
	var d := LevelDef.new()
	d.id = id
	d.level = level
	d.min_best_skill = best
	d.min_total_exp = exp
	d.salary_bp = salary
	d.output_bp = output
	return d


static func _size(id: StringName, weeks: int, staff: int, cost_bp: int, audience: int, price: int, par: int) -> ProjectSizeDef:
	var d := ProjectSizeDef.new()
	d.id = id
	d.name_key = StringName("fx.%s" % id)
	d.base_weeks = weeks
	d.min_staff = staff
	d.cost_multiplier_bp = cost_bp
	d.audience_bp = audience
	d.price = price
	d.par_points = par
	return d


static func _platform(id: StringName, kind: StringName, launch: int, end: int, kit: int, rumor: int, ceiling: int, curve: Array[int], fit: Dictionary) -> PlatformDef:
	var d := PlatformDef.new()
	d.id = id
	d.name_key = StringName("fx.%s" % id)
	d.kind = kind
	d.launch_week = launch
	d.end_week = end
	d.dev_kit_cost = kit
	d.rumor_weeks = rumor
	d.tech_ceiling = ceiling
	d.install_curve = curve
	d.genre_fit_bp.assign(fit)
	return d


static func _genre(id: StringName, sliders: Array[int]) -> GenreDef:
	var d := GenreDef.new()
	d.id = id
	d.name_key = StringName("fx.%s" % id)
	d.ideal_sliders = sliders
	return d


static func _topic(id: StringName, fit: Dictionary) -> TopicDef:
	var d := TopicDef.new()
	d.id = id
	d.name_key = StringName("fx.%s" % id)
	d.genre_fit_bp.assign(fit)
	return d


static func _feature(id: StringName, research_id: StringName, cap: int, weeks: int) -> EngineFeatureDef:
	var d := EngineFeatureDef.new()
	d.id = id
	d.name_key = StringName("fx.%s" % id)
	d.research_id = research_id
	d.tech_cap_add = cap
	d.dev_weeks = weeks
	return d


static func _research(id: StringName, cost: int, prereq: Array[StringName], unlocks: Array[StringName]) -> ResearchDef:
	var d := ResearchDef.new()
	d.id = id
	d.name_key = StringName("fx.%s" % id)
	d.cost_rp = cost
	d.prerequisites = prereq
	d.unlocks = unlocks
	return d


static func _lic_engine(id: StringName, from: int, to: int, fee: int, royalty: int, cap: int, features: Array[StringName]) -> LicensedEngineDef:
	var d := LicensedEngineDef.new()
	d.id = id
	d.name_key = StringName("fx.%s" % id)
	d.year_from = from
	d.year_to = to
	d.fee = fee
	d.royalty_bp = royalty
	d.tech_cap = cap
	d.features = features
	return d


static func _outlet(id: StringName, weights: Dictionary, bias: int) -> ReviewOutletDef:
	var d := ReviewOutletDef.new()
	d.id = id
	d.name_key = StringName("fx.%s" % id)
	d.weights_bp.assign(weights)
	d.bias_x10 = bias
	return d


static func _template(id: StringName, dim: StringName, strength: bool, threshold: int, key: StringName) -> ReviewTemplateDef:
	var d := ReviewTemplateDef.new()
	d.id = id
	d.dimension = dim
	d.is_strength = strength
	d.threshold_x10 = threshold
	d.text_key = key
	return d
