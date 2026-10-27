class_name HiringSystem
extends RefCounted
## M2 spec 5 step 15: candidate expiry weekly, a fresh pool each month start.


static func tick(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	var expired: Array[int] = []
	for c: Candidate in state.candidates:
		if c.expires_week <= state.week:
			expired.append(c.id)
	for id: int in expired:
		Removal.remove_candidate(state, id)
	if Calendar.is_month_start(state.week, ctx.tuning):
		for i: int in ctx.tuning.candidates_per_month:
			state.candidates.append(_make(ctx))


static func _make(ctx: TickContext) -> Candidate:
	var t: TuningDef = ctx.tuning
	var c := Candidate.new()
	c.id = ctx.state.alloc_id()
	c.expires_week = ctx.state.week + t.candidate_expiry_weeks
	c.name = "staff_name.%02d" % ctx.rng.randi_range(1, t.candidate_name_count)
	var total: int = 0
	for w: int in t.candidate_level_weights:
		total += w
	var roll: int = ctx.rng.randi_range(0, total - 1)
	for i: int in t.candidate_level_weights.size():
		if roll < t.candidate_level_weights[i]:
			c.level = i
			break
		roll -= t.candidate_level_weights[i]
	var skill_mult: int = Fixed.ONE_BP + PeopleRules.effect_bp(ctx.state, ctx.content, &"candidate_skill_bp")
	var drawn: Dictionary[StringName, int] = {}
	for skill: StringName in GameRules.SKILL_ORDER:
		var v: int = ctx.rng.randi_range(t.hire_skill_min, t.hire_skill_max) + t.candidate_level_skill_bonus[c.level]
		drawn[skill] = clampi(Fixed.mul_bp(v, skill_mult), 1, 100)
	for k: StringName in GameState.sorted_names(drawn):
		c.skills[k] = drawn[k]
	var noise: int = ctx.rng.randi_range(t.candidate_salary_noise_min_pct, t.candidate_salary_noise_max_pct)
	var market: int = PeopleRules.market_salary(c.skills, c.level, ctx.content, t)
	c.asking_salary = Fixed.mul_bp(Fixed.mul_bp(market, Fixed.ONE_BP + noise * 100),
		Fixed.ONE_BP + PeopleRules.effect_bp(ctx.state, ctx.content, &"asking_salary_bp"))
	return c
