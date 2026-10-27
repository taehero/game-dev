class_name PeopleRules
extends RefCounted
## Stateless people maths: salary, perks, chemistry, equipment age. No RNG.

const EFFECTS: Array[StringName] = [&"skill_design", &"skill_tech", &"skill_art", &"skill_audio",
	&"engine_speed_bp", &"owner_burnout_bp", &"contract_pay_bp", &"publisher_share_bp", &"candidate_skill_bp",
	&"asking_salary_bp", &"hype_gain_bp", &"loan_rate_bp", &"chemistry_bp", &"morale_baseline_bp"]


## Sum of owner perk effects. BUSINESS perks are scaled by (ONE_BP - focus_dev_bp).
static func effect_bp(state: GameState, content: ContentDB, effect: StringName) -> int:
	var total: int = 0
	for perk_id: StringName in GameState.sorted_names(state.owner.perks):
		if not content.perks.has(perk_id):
			continue
		var def: PerkDef = content.perks[perk_id]
		var term: int = state.owner.perks[perk_id] * def.effects_bp_per_rank.get(effect, 0)
		if def.path == &"BUSINESS":
			term = Fixed.mul_bp(term, Fixed.ONE_BP - state.owner.focus_dev_bp)
		total += term
	return total


static func _level_def(level: int, content: ContentDB) -> LevelDef:
	for id: StringName in GameState.sorted_names(content.levels):
		if content.levels[id].level == level:
			return content.levels[id]
	return null


static func market_salary(skills: Dictionary[StringName, int], level: int, content: ContentDB, t: TuningDef) -> int:
	var sum: int = 0
	for k: StringName in skills:
		sum += skills[k]
	var base: int = t.era_wage_base + sum * t.wage_per_skill_point
	var def: LevelDef = _level_def(level, content)
	return Fixed.mul_bp(base, def.salary_bp if def != null else Fixed.ONE_BP)


static func promotion_eligible(s: Staff, content: ContentDB) -> bool:
	var next: int = int(s.level) + 1
	if next > int(Staff.Level.LEAD):
		return false
	var def: LevelDef = _level_def(next, content)
	if def == null:
		return false
	var best: int = 0
	for k: StringName in s.skills:
		best = maxi(best, s.skills[k])
	var total: int = 0
	for k: StringName in s.exp:
		total += s.exp[k]
	return best >= def.min_best_skill and total >= def.min_total_exp


static func owner_point_bp(state: GameState, s: Staff) -> int:
	return state.owner.focus_dev_bp if s.id == state.owner_staff_id() else Fixed.ONE_BP


static func progress_bp(state: GameState, content: ContentDB, p: Project) -> int:
	if p.kind == Project.Kind.ENGINE:
		return Fixed.ONE_BP + effect_bp(state, content, &"engine_speed_bp")
	return Fixed.ONE_BP


static func chemistry_bp(state: GameState, content: ContentDB, t: TuningDef, project_id: int, staff_id: int) -> int:
	var chem: int = Fixed.ONE_BP
	for sid: int in GameRules.working_staff(state, project_id):
		if sid != staff_id and state.staff[sid].level == Staff.Level.LEAD:
			chem += t.lead_chemistry_bp
			break
	if staff_id != state.owner_staff_id():
		chem += effect_bp(state, content, &"chemistry_bp")
	return chem


static func _outdated(def: EquipmentDef, week: int, t: TuningDef) -> bool:
	return Calendar.year(week, t) > def.recommended_until_year


static func equipment_speed_bp(def: EquipmentDef, week: int, t: TuningDef) -> int:
	if def == null or not _outdated(def, week, t):
		return Fixed.ONE_BP
	return t.outdated_speed_bp


static func equipment_bug_bp(def: EquipmentDef, week: int, t: TuningDef) -> int:
	if def == null or not _outdated(def, week, t):
		return Fixed.ONE_BP
	return t.outdated_bug_bp


static func equipment_available(def: EquipmentDef, week: int, t: TuningDef) -> bool:
	return def != null and Calendar.year(week, t) >= def.year_from


static func morale_baseline(state: GameState, content: ContentDB, t: TuningDef) -> int:
	return clampi(t.morale_baseline + Fixed.mul_bp(100, effect_bp(state, content, &"morale_baseline_bp")), 0, 100)
