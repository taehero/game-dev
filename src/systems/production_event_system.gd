class_name ProductionEventSystem
extends RefCounted
## Mid-production events (M2d Rulings P4-P7). An event is a Decision whose kind is a ProductionEventDef id.
## RNG order per tick: projects by sorted id; each eligible project draws one Fixed.roll_bp, and on a hit
## one randi_range(0, n - 1) over the sorted not-yet-seen event ids. Ineligible projects draw nothing.


static func tick(ctx: TickContext) -> void:
	_expire(ctx)
	_roll(ctx)


static func is_event_decision(content: ContentDB, d: Decision) -> bool:
	return content.production_events.has(d.kind)


## Id of the pending event decision about the project, or -1.
static func pending_for(state: GameState, content: ContentDB, project_id: int) -> int:
	for d: Decision in state.pending_decisions:
		if is_event_decision(content, d) and d.related_ids.has(project_id):
			return d.id
	return -1


## P6: expired events vanish with no effect. Ids are copied and sorted ascending first.
static func _expire(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	var expired: Array[int] = []
	for d: Decision in state.pending_decisions:
		if is_event_decision(ctx.content, d) and d.deadline_week <= state.week:
			expired.append(d.id)
	expired.sort()
	for did: int in expired:
		Removal.remove_decision(state, did)


static func _roll(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	if ctx.content.production_events.is_empty():
		return
	var all_ids: Array[StringName] = GameState.sorted_names(ctx.content.production_events)
	for pid: int in state.sorted_ids(state.projects):
		var p: Project = state.projects[pid]
		if p.company_id != state.player_company_id:
			continue
		if p.kind != Project.Kind.GAME or p.phase != Project.Phase.PRODUCTION:
			continue
		if GameRules.working_staff(state, pid).is_empty():
			continue
		if p.event_ids.size() >= ctx.tuning.production_event_max_per_project:
			continue
		if pending_for(state, ctx.content, pid) != -1:
			continue
		var unseen: Array[StringName] = []
		for eid: StringName in all_ids:
			if not p.event_ids.has(eid):
				unseen.append(eid)
		if unseen.is_empty():
			continue
		if not Fixed.roll_bp(ctx.rng, ctx.tuning.production_event_chance_bp):
			continue
		var def: ProductionEventDef = ctx.content.production_events[unseen[ctx.rng.randi_range(0, unseen.size() - 1)]]
		var dec := Decision.new()
		dec.id = state.alloc_id()
		dec.kind = def.id
		dec.related_ids.assign([pid])
		dec.deadline_week = state.week + ctx.tuning.production_event_answer_weeks
		dec.option_keys.assign(def.option_keys)
		state.pending_decisions.append(dec)
		p.event_ids.append(def.id)


## P7: closed effect set in ProductionEventDef.EFFECTS order. Never mutates the def's dictionaries.
static func apply_effects(ctx: TickContext, def: ProductionEventDef, option_index: int, project_id: int) -> void:
	var state: GameState = ctx.state
	var p: Project = state.projects[project_id]
	var fx: Dictionary[StringName, int] = def.option_effects(option_index)
	for key: StringName in ProductionEventDef.EFFECTS:
		if not fx.has(key):
			continue
		var amount: int = fx[key]
		match key:
			&"bugs":
				p.bugs = maxi(0, p.bugs + amount)
			&"hype":
				p.hype = clampi(p.hype + amount, 0, 100)
			&"morale":
				for sid: int in state.sorted_ids(state.staff):
					var st: Staff = state.staff[sid]
					if st.assigned_project_id == project_id:
						st.morale = clampi(st.morale + amount, 0, 100)
			&"progress_bp":
				if p.phase == Project.Phase.PRODUCTION:
					p.stage_progress = clampi(p.stage_progress + amount, 0, Fixed.ONE_BP - 1)
			_:
				var total: int = maxi(0, int(p.points.get(key, 0)) + amount)
				if p.points.has(key) or total > 0:
					_set_point(p, key, total)


## Inserts keys in sorted order so live and loaded dictionaries share one order.
static func _set_point(p: Project, type: StringName, value: int) -> void:
	if p.points.has(type):
		p.points[type] = value
		return
	var copy: Dictionary[StringName, int] = p.points.duplicate()
	copy[type] = value
	p.points.clear()
	for k: StringName in GameState.sorted_names(copy):
		p.points[k] = copy[k]
