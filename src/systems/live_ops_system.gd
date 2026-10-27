class_name LiveOpsSystem
extends RefCounted


static func tick(ctx: TickContext) -> void:
	_tick_tasks(ctx)  # Spec 4.2 step 8: live-ops updates and support.
	_tick_dlc_launches(ctx)


static func change_sentiment(p: Project, delta: int) -> void:
	p.sentiment = clampi(p.sentiment + delta, -100, 100)


static func release_task_staff(state: GameState, project_id: int) -> void:
	for sid: int in state.sorted_ids(state.staff):
		if state.staff[sid].assigned_project_id == project_id:
			state.staff[sid].assigned_project_id = -1


## Shared validation for StartPatch and BuildModTools; &"" when the task may start.
static func live_task_block_key(state: GameState, project_id: int) -> StringName:
	if not state.projects.has(project_id):
		return &"error.project_not_found"
	var p: Project = state.projects[project_id]
	if p.kind != Project.Kind.GAME or p.phase != Project.Phase.LIVE:
		return &"error.project_not_live"
	if p.live_task != Project.LiveTask.NONE:
		return &"error.live_task_running"
	if GameRules.free_workers(state, p.company_id).is_empty():
		return &"error.not_enough_staff"
	return &""


static func start_task(ctx: TickContext, project_id: int, task: Project.LiveTask, staff_weeks: int) -> void:
	var p: Project = ctx.state.projects[project_id]
	p.live_task = task
	p.live_task_left = staff_weeks
	for sid: int in GameRules.free_workers(ctx.state, p.company_id):
		ctx.state.staff[sid].assigned_project_id = project_id
	ctx.emit(&"project_changed", {"project_id": project_id})


static func _tick_tasks(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	var t: TuningDef = ctx.tuning
	for pid: int in state.sorted_ids(state.projects):
		var p: Project = state.projects[pid]
		if p.live_task == Project.LiveTask.NONE:
			continue
		if p.phase != Project.Phase.LIVE:
			p.live_task = Project.LiveTask.NONE
			p.live_task_left = 0
			release_task_staff(state, pid)
			ctx.emit(&"project_changed", {"project_id": pid})
			continue
		for _sid: int in GameRules.working_staff(state, pid):
			if p.live_task == Project.LiveTask.PATCH:
				p.bugs = maxi(0, p.bugs - t.patch_bugs_per_staff_week)
			p.live_task_left -= 1
		if p.live_task_left > 0:
			continue
		var done: String = Project.LiveTask.keys()[p.live_task]
		if p.live_task == Project.LiveTask.PATCH:
			p.user_score = mini(100, p.user_score + t.patch_user_score_x10)
			change_sentiment(p, t.patch_sentiment)
		else:
			p.mod_tools = true
		p.live_task = Project.LiveTask.NONE
		p.live_task_left = 0
		release_task_staff(state, pid)
		ctx.emit(&"project_changed", {"project_id": pid, "live_task_done": done})


static func _tick_dlc_launches(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	var t: TuningDef = ctx.tuning
	for pid: int in state.sorted_ids(state.projects):
		var d: Project = state.projects[pid]
		if d.parent_id == -1 or d.phase != Project.Phase.LIVE or d.weekly_units.size() != 1:
			continue
		if not state.projects.has(d.parent_id):
			continue
		var parent: Project = state.projects[d.parent_id]
		if parent.phase != Project.Phase.LIVE:
			continue
		var uplift: int = maxi(0, t.dlc_tail_uplift_bp - (t.mod_dlc_penalty_bp if parent.mod_tools else 0))
		parent.sales_base_units = Fixed.mul_bp(parent.sales_base_units, Fixed.ONE_BP + uplift)
		ctx.emit(&"project_changed", {"project_id": parent.id})
