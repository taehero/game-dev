class_name AwardsSystem
extends RefCounted


## The smallest week after `week` that falls on the award's week of the year.
static func next_ceremony_week(def: AwardDef, week: int, t: TuningDef) -> int:
	var c: int = week + 1
	while Calendar.week_in_year(c, t) != def.week_in_year:
		c += 1
	return c


static func eligible(p: Project, ceremony_week: int, t: TuningDef) -> bool:
	if p.kind != Project.Kind.GAME or p.parent_id != -1 or p.release_week < 0 or p.review_results.is_empty():
		return false
	var age: int = ceremony_week - p.release_week
	return age >= 0 and age <= t.award_window_weeks


static func entry_score_x10(p: Project) -> int:
	if p.review_results.is_empty():
		return 0
	var sum: int = 0
	for r: ReviewResult in p.review_results:
		sum += r.score_x10
	@warning_ignore("integer_division")
	return sum / p.review_results.size()


static func tick(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	var t: TuningDef = ctx.tuning
	var wiy: int = Calendar.week_in_year(state.week, t)
	for award_id: StringName in GameState.sorted_names(ctx.content.awards):
		var def: AwardDef = ctx.content.awards[award_id]
		if def.week_in_year != wiy:
			continue
		var best_pid: int = -1
		var best: int = -1
		var any_entry: bool = false
		for pid: int in state.sorted_ids(state.projects):
			var p: Project = state.projects[pid]
			if p.award_entry != award_id:
				continue
			any_entry = true
			p.award_entry = &""
			if not eligible(p, state.week, t):
				continue
			var score: int = entry_score_x10(p) + ctx.rng.randi_range(0, t.award_bonus_max_x10)
			if score > best:
				best = score
				best_pid = pid
		if not any_entry:
			continue
		if best_pid == -1:
			ctx.emit(&"award_result", {"award_id": award_id, "project_id": -1, "score_x10": 0, "ai_best_x10": 0, "won": false})
			continue
		var ai_best: int = 0
		for _i: int in t.award_ai_entries:
			ai_best = maxi(ai_best, ctx.rng.randi_range(t.award_ai_score_min_x10, t.award_ai_score_max_x10))
		var won: bool = best > ai_best
		if won:
			var c: Company = state.companies[state.projects[best_pid].company_id]
			c.money += def.prize
			c.fan_count += def.fans
			c.reputation = mini(100, c.reputation + t.award_reputation)
			c.awards.append(award_id)
			ctx.emit(&"money_changed", {"company_id": c.id, "money": c.money})
		ctx.emit(&"award_result", {"award_id": award_id, "project_id": best_pid, "score_x10": best, "ai_best_x10": ai_best, "won": won})
