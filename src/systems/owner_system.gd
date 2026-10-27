class_name OwnerSystem
extends RefCounted
## M2 spec 5 step 6: owner xp, skill points and the neglect penalty. No RNG.


static func tick(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	var t: TuningDef = ctx.tuning
	var o: OwnerProfile = state.owner
	var gain: int = 0
	if state.staff.has(o.staff_id):
		for k: StringName in GameState.sorted_names(state.staff[o.staff_id].week_points):
			gain += state.staff[o.staff_id].week_points[k]
	for pid: int in state.sorted_ids(state.projects):
		var p: Project = state.projects[pid]
		if p.company_id == state.player_company_id and p.kind == Project.Kind.GAME \
				and p.phase == Project.Phase.RELEASED and p.weekly_units.is_empty():
			gain += t.owner_xp_per_release
	if gain > 0:
		var old: int = o.xp
		o.xp += gain
		@warning_ignore("integer_division")
		o.skill_points += o.xp / t.owner_xp_per_point - old / t.owner_xp_per_point
	if Calendar.is_month_start(state.week, t):
		var others: Array[int] = []
		for sid: int in state.staff_of(state.player_company_id):
			if not state.staff[sid].is_owner:
				others.append(sid)
		if others.size() > t.owner_solo_limit and o.focus_dev_bp > t.owner_neglect_focus_bp:
			for sid: int in others:
				var s: Staff = state.staff[sid]
				s.morale = clampi(s.morale + t.owner_neglect_morale, 0, 100)
