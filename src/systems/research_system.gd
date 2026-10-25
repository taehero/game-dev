class_name ResearchSystem
extends RefCounted


## M2 spec 5 step 7. Reads the week_points Production wrote last tick (Ruling A4).
static func tick(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	var totals: Dictionary[int, int] = {}
	for staff_id: int in state.sorted_ids(state.staff):
		var s: Staff = state.staff[staff_id]
		var sum: int = 0
		for skill: StringName in GameState.sorted_names(s.week_points):
			sum += s.week_points[skill]
		totals[s.company_id] = totals.get(s.company_id, 0) + sum
	for company_id: int in state.sorted_ids(state.companies):
		var gained: int = Fixed.mul_bp(totals.get(company_id, 0), ctx.tuning.research_per_point_bp)
		state.companies[company_id].research_points += gained
