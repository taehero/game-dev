class_name ProductionSystem
extends RefCounted
## Spec 6.2-6.4. Per project per week: sliders to points, bug rolls, stage progress (PRODUCTION),
## bug fixing (POLISH). RNG order: projects by sorted id, working staff by sorted id,
## exactly one roll per working staff per PRODUCTION week.


@warning_ignore("integer_division")
static func morale_bp(morale: int, t: TuningDef) -> int:
	return t.morale_factor_min_bp + (t.morale_factor_max_bp - t.morale_factor_min_bp) * morale / 100


@warning_ignore("integer_division")
static func engine_age_bp(state: GameState, content: ContentDB, p: Project, t: TuningDef) -> int:
	if p.kind == Project.Kind.ENGINE:
		return Fixed.ONE_BP
	var years: int = 0
	if state.engines.has(p.engine_id):
		years = (state.week - state.engines[p.engine_id].built_week) / t.weeks_per_year
	else:
		var def: LicensedEngineDef = GameRules.project_licensed_engine(state, content, p)
		if def != null:
			years = Calendar.year(state.week, t) - def.year_from
	return Fixed.ONE_BP + maxi(0, years) * t.engine_age_bug_bp_per_year


static func tick(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	for sid: int in state.sorted_ids(state.staff):
		state.staff[sid].week_points = {}
	for pid: int in state.sorted_ids(state.projects):
		var p: Project = state.projects[pid]
		if p.kind == Project.Kind.CONTRACT_WORK:
			if p.phase == Project.Phase.PRODUCTION:
				_produce_contract(ctx, p)
			continue
		if p.kind != Project.Kind.GAME and p.kind != Project.Kind.ENGINE:
			continue
		if p.phase == Project.Phase.PRODUCTION:
			_produce(ctx, p)
		elif p.phase == Project.Phase.POLISH:
			_polish(ctx, p)


static func _equipment_def(ctx: TickContext, staff: Staff) -> EquipmentDef:
	var eid: int = GameRules.equipment_at_seat(ctx.state, staff.company_id, staff.seat_index)
	if eid == -1:
		return null
	return ctx.content.equipment.get(ctx.state.equipment[eid].def_id)


static func _produce(ctx: TickContext, p: Project) -> void:
	var state: GameState = ctx.state
	var t: TuningDef = ctx.tuning
	var ws: Array[int] = GameRules.working_staff(state, p.id)
	if ws.is_empty():
		return
	var age_bp: int = engine_age_bp(state, ctx.content, p, t)

	# Steps 3 and 4 share one pass over staff, so the order is: points events of a staff, then its bug roll.
	for sid: int in ws:
		var st: Staff = state.staff[sid]
		var eq: EquipmentDef = _equipment_def(ctx, st)
		var speed_bp: int = PeopleRules.equipment_speed_bp(eq, state.week, t)
		var bug_eq_bp: int = PeopleRules.equipment_bug_bp(eq, state.week, t)
		var lvl: LevelDef = ctx.content.level_def(int(st.level))
		var output_bp: int = lvl.output_bp if lvl != null else Fixed.ONE_BP
		var morale: int = morale_bp(st.morale, t)
		var chem: int = PeopleRules.chemistry_bp(state, ctx.content, t, p.id, sid)
		var owner_bp: int = PeopleRules.owner_point_bp(state, st)

		var gained: Dictionary[StringName, int] = {}
		var order: Array[StringName] = []
		for j: int in 3:
			var i: int = p.stage_index * 3 + j
			var type: StringName = GameRules.SLIDER_TYPES[i]
			var amount: int = int(st.skills.get(type, 0)) * t.points_per_skill
			amount = Fixed.mul_bp(amount, p.focus[i])
			amount = Fixed.mul_bp(amount, speed_bp)
			amount = Fixed.mul_bp(amount, morale)
			amount = Fixed.mul_bp(amount, output_bp)
			amount = Fixed.mul_bp(amount, chem)
			amount = Fixed.mul_bp(amount, owner_bp)
			if amount <= 0:
				continue
			if not gained.has(type):
				gained[type] = 0
				order.append(type)
			gained[type] += amount
		for type: StringName in order:
			_add_points(p, type, gained[type])
			st.week_points[type] = int(st.week_points.get(type, 0)) + gained[type]
			ctx.emit(&"points_gained", {"staff_id": sid, "project_id": p.id, "type": type, "amount": gained[type]})

		var b: int = t.bugs_per_staff_week_bp
		if p.crunch:
			b = Fixed.mul_bp(b, t.crunch_bug_bp)
		b = Fixed.mul_bp(b, bug_eq_bp)
		b = Fixed.mul_bp(b, age_bp)
		b = Fixed.mul_bp(b, maxi(0, 2 * Fixed.ONE_BP - chem))
		@warning_ignore("integer_division")
		var n: int = b / Fixed.ONE_BP
		if Fixed.roll_bp(ctx.rng, b % Fixed.ONE_BP):
			n += 1
		p.bugs += n
		for k: int in n:
			ctx.emit(&"bug_found", {"staff_id": sid, "project_id": p.id})

	# Step 5: progress. Ceiling division (Ruling A13).
	var working: int = mini(ws.size(), GameRules.min_staff(p, ctx.content, t))
	var d: int = GameRules.stage_weeks(p, ctx.content, t) * GameRules.min_staff(p, ctx.content, t)
	@warning_ignore("integer_division")
	var inc: int = (Fixed.ONE_BP * working + d - 1) / d
	inc = Fixed.mul_bp(inc, PeopleRules.progress_bp(state, ctx.content, p))
	if p.crunch:
		inc = Fixed.mul_bp(inc, t.crunch_speed_bp)
	p.stage_progress += inc
	if p.stage_progress < Fixed.ONE_BP:
		return
	p.stage_progress = 0
	if p.stage_index + 1 < GameRules.stage_count(p):
		p.stage_index += 1
		ctx.emit(&"project_stage_changed", {"project_id": p.id, "stage_index": p.stage_index})
	elif p.kind == Project.Kind.GAME:
		p.phase = Project.Phase.POLISH
		ctx.emit(&"project_phase_changed", {"project_id": p.id, "phase": "POLISH"})
	else:
		_finish_engine(ctx, p)


## Ruling B10: no bugs, no RNG, no stage progress; stays in PRODUCTION until settled.
static func _produce_contract(ctx: TickContext, p: Project) -> void:
	var state: GameState = ctx.state
	var t: TuningDef = ctx.tuning
	if not state.contracts.has(p.contract_id):
		return
	var targets: Dictionary[StringName, int] = state.contracts[p.contract_id].target_points
	var types: Array[StringName] = []
	for type: StringName in GameRules.SKILL_ORDER:
		if targets.get(type, 0) > 0:
			types.append(type)
	if types.is_empty():
		return
	for sid: int in GameRules.working_staff(state, p.id):
		var st: Staff = state.staff[sid]
		var eq: EquipmentDef = _equipment_def(ctx, st)
		var lvl: LevelDef = ctx.content.level_def(int(st.level))
		var output_bp: int = lvl.output_bp if lvl != null else Fixed.ONE_BP
		var chem: int = PeopleRules.chemistry_bp(state, ctx.content, t, p.id, sid)
		for type: StringName in types:
			var amount: int = int(st.skills.get(type, 0)) * t.points_per_skill
			@warning_ignore("integer_division")
			amount = Fixed.mul_bp(amount, Fixed.ONE_BP / types.size())
			amount = Fixed.mul_bp(amount, PeopleRules.equipment_speed_bp(eq, state.week, t))
			amount = Fixed.mul_bp(amount, morale_bp(st.morale, t))
			amount = Fixed.mul_bp(amount, output_bp)
			amount = Fixed.mul_bp(amount, chem)
			amount = Fixed.mul_bp(amount, PeopleRules.owner_point_bp(state, st))
			if amount <= 0:
				continue
			_add_points(p, type, amount)
			st.week_points[type] = int(st.week_points.get(type, 0)) + amount
			ctx.emit(&"points_gained", {"staff_id": sid, "project_id": p.id, "type": type, "amount": amount})


static func _finish_engine(ctx: TickContext, p: Project) -> void:
	var state: GameState = ctx.state
	var cap: int = ctx.tuning.engine_base_tech_cap
	for f: StringName in p.features:
		if ctx.content.engine_features.has(f):
			cap += ctx.content.engine_features[f].tech_cap_add
	var e := GameEngine.new()
	e.id = state.alloc_id()
	e.company_id = p.company_id
	e.name = p.title
	e.features.assign(p.features)
	e.tech_cap = mini(100, cap)
	e.source = GameEngine.Source.BUILT
	e.built_week = state.week
	state.engines[e.id] = e
	p.phase = Project.Phase.RETIRED
	for sid: int in state.sorted_ids(state.staff):
		if state.staff[sid].assigned_project_id == p.id:
			state.staff[sid].assigned_project_id = -1
	ctx.emit(&"project_phase_changed", {"project_id": p.id, "phase": "RETIRED", "engine_id": e.id})


static func _polish(ctx: TickContext, p: Project) -> void:
	var ws: Array[int] = GameRules.working_staff(ctx.state, p.id)
	if ws.is_empty():
		return
	p.bugs = maxi(0, p.bugs - ctx.tuning.polish_bugs_fixed_per_staff_week * ws.size())


## Inserts keys in sorted order so live and loaded dictionaries share one order.
static func _add_points(p: Project, type: StringName, amount: int) -> void:
	if p.points.has(type):
		p.points[type] += amount
		return
	var copy: Dictionary[StringName, int] = p.points.duplicate()
	copy[type] = amount
	p.points.clear()
	for k: StringName in GameState.sorted_names(copy):
		p.points[k] = copy[k]
