class_name StaffSystem
extends RefCounted
## Spec 4.2 step 4: staff exp, morale, burnout, raise/promotion asks and resignations.


static func tick(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	var t: TuningDef = ctx.tuning
	for d: Decision in state.pending_decisions.duplicate():
		if AnswerRaiseCommand.KINDS.has(d.kind) and d.deadline_week <= state.week and not d.related_ids.is_empty():
			AnswerRaiseCommand.resolve(state, t, d.related_ids[0], false)
	for sid: int in state.sorted_ids(state.staff):
		if not state.staff.has(sid):
			continue
		var s: Staff = state.staff[sid]
		var is_owner: bool = sid == state.owner_staff_id()
		_exp(s, t)
		_mood(ctx, s, is_owner)
		_ask(ctx, s, is_owner)
		if not is_owner and _resigns(ctx, s):
			Removal.remove_staff(state, sid)
			ctx.emit(&"staff_resigned", {"staff_id": sid})


static func _exp(s: Staff, t: TuningDef) -> void:
	for k: StringName in GameState.sorted_names(s.week_points):
		var old: int = s.exp.get(k, 0)
		var new_exp: int = old + Fixed.mul_bp(s.week_points[k], t.staff_exp_per_point_bp)
		s.exp[k] = new_exp
		@warning_ignore("integer_division")
		var gain: int = new_exp / 100 - old / 100
		s.skills[k] = clampi(s.skills.get(k, 0) + gain, 0, 100)


static func _mood(ctx: TickContext, s: Staff, is_owner: bool) -> void:
	var state: GameState = ctx.state
	var t: TuningDef = ctx.tuning
	var crunching: bool = false
	if state.projects.has(s.assigned_project_id):
		var p: Project = state.projects[s.assigned_project_id]
		crunching = p.phase == Project.Phase.PRODUCTION and p.crunch \
			and GameRules.working_staff(state, p.id).has(s.id)
	if crunching:
		var gain: int = t.crunch_burnout_per_week
		if is_owner:
			gain = Fixed.mul_bp(gain, Fixed.ONE_BP + PeopleRules.effect_bp(state, ctx.content, &"owner_burnout_bp"))
		s.burnout = clampi(s.burnout + gain, 0, 100)
		s.morale = clampi(s.morale + t.crunch_morale_per_week, 0, 100)
	else:
		s.burnout = clampi(s.burnout - t.burnout_recovery_per_week, 0, 100)
		var base: int = PeopleRules.morale_baseline(state, ctx.content, t)
		s.morale = clampi(s.morale + clampi(base - s.morale, -t.morale_recovery_per_week, t.morale_recovery_per_week), 0, 100)


static func _ask(ctx: TickContext, s: Staff, is_owner: bool) -> void:
	var state: GameState = ctx.state
	var t: TuningDef = ctx.tuning
	var eligible: bool = PeopleRules.promotion_eligible(s, ctx.content)
	if is_owner:
		if eligible:
			s.level = (int(s.level) + 1) as Staff.Level
		return
	if AnswerRaiseCommand.find_ask(state, s.id) != null:
		return
	var promotion: bool = eligible and state.week - s.last_raise_week >= t.promotion_ask_cooldown_weeks
	var amount: int = 0
	if promotion:
		amount = PeopleRules.market_salary(s.skills, int(s.level) + 1, ctx.content, t)
	elif state.week > s.hired_week and (state.week - s.hired_week) % t.weeks_per_year == 0:
		var market: int = PeopleRules.market_salary(s.skills, int(s.level), ctx.content, t)
		if s.salary < Fixed.mul_bp(market, t.raise_threshold_bp):
			amount = market
	if amount <= 0:
		return
	s.asking_raise = amount
	var dec := Decision.new()
	dec.id = state.alloc_id()
	dec.kind = &"promotion_request" if promotion else &"raise_request"
	dec.related_ids.assign([s.id])
	dec.deadline_week = state.week + t.raise_answer_weeks
	dec.option_keys.assign([&"ui.decision.accept", &"ui.decision.refuse"])
	state.pending_decisions.append(dec)
	ctx.emit(&"raise_requested", {"staff_id": s.id, "amount": amount, "promotion": promotion})


static func _resigns(ctx: TickContext, s: Staff) -> bool:
	var t: TuningDef = ctx.tuning
	if s.burnout < t.resign_burnout_threshold and s.morale > t.resign_morale_threshold:
		return false
	var chance: int = t.resign_base_chance_bp \
		+ maxi(0, s.burnout - t.resign_burnout_threshold) * t.resign_chance_per_burnout_bp
	if s.raise_refusals >= t.resign_refusals_double:
		chance *= 2
	return Fixed.roll_bp(ctx.rng, chance)
