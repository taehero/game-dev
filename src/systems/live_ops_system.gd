class_name LiveOpsSystem
extends RefCounted


static func tick(ctx: TickContext) -> void:
	_tick_tasks(ctx)  # Spec 4.2 step 8: live-ops updates and support.
	_tick_dlc_launches(ctx)
	_tick_forum(ctx)
	if Calendar.is_month_start(ctx.state.week, ctx.tuning):
		_tick_viral(ctx)


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


## Error key if `ids` is not a valid unique subset of the company's free workers (empty = ok, means everyone).
static func staff_choice_key(state: GameState, company_id: int, ids: Array[int]) -> StringName:
	var free: Array[int] = GameRules.free_workers(state, company_id)
	var seen: Dictionary = {}
	for sid: int in ids:
		if not state.staff.has(sid):
			return &"error.staff_not_found"
		if seen.has(sid) or not free.has(sid):
			return &"error.not_enough_staff"
		seen[sid] = true
	return &""


## Chosen ids, or every free worker when `ids` is empty.
static func staff_to_assign(state: GameState, company_id: int, ids: Array[int]) -> Array[int]:
	return ids if not ids.is_empty() else GameRules.free_workers(state, company_id)


static func start_task(ctx: TickContext, project_id: int, task: Project.LiveTask, staff_weeks: int, staff_ids: Array[int] = []) -> void:
	var p: Project = ctx.state.projects[project_id]
	p.live_task = task
	p.live_task_left = staff_weeks
	for sid: int in staff_to_assign(ctx.state, p.company_id, staff_ids):
		ctx.state.staff[sid].assigned_project_id = project_id
	ctx.emit(&"project_changed", {"project_id": project_id})


## True while any staff member is assigned to the project (seated or not).
static func _anyone_assigned(state: GameState, project_id: int) -> bool:
	for sid: int in state.sorted_ids(state.staff):
		if state.staff[sid].assigned_project_id == project_id:
			return true
	return false


static func _tick_tasks(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	var t: TuningDef = ctx.tuning
	for pid: int in state.sorted_ids(state.projects):
		var p: Project = state.projects[pid]
		if p.live_task == Project.LiveTask.NONE:
			continue
		if p.phase != Project.Phase.LIVE or not _anyone_assigned(state, pid):
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


static func forum_chance_bp(p: Project, t: TuningDef) -> int:
	return mini(t.forum_post_max_chance_bp, t.forum_post_base_chance_bp + p.bugs * t.forum_post_chance_per_bug_bp)


static func add_forum_post(ctx: TickContext, project_id: int, topic_key: StringName, sentiment: int, replied: bool) -> int:
	var state: GameState = ctx.state
	var f := ForumPost.new()
	f.id = state.alloc_id()
	f.project_id = project_id
	f.week = state.week
	f.topic_key = topic_key
	f.sentiment = sentiment
	f.replied = replied
	state.forum_posts.append(f)
	change_sentiment(state.projects[project_id], sentiment)
	while state.forum_posts.size() > ctx.tuning.forum_posts_cap:
		Removal.remove_forum_post(state, state.forum_posts[0].id)
	if not state.forum_posts.has(f):
		return -1
	ctx.emit(&"forum_post_created", {"post_id": f.id, "project_id": project_id, "topic_key": topic_key})
	return f.id


static func _tick_forum(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	for pid: int in state.sorted_ids(state.projects):
		var p: Project = state.projects[pid]
		if p.kind != Project.Kind.GAME or p.phase != Project.Phase.LIVE:
			continue
		if not Fixed.roll_bp(ctx.rng, forum_chance_bp(p, ctx.tuning)):
			continue
		var has_bugs: bool = p.bugs > 0
		var has_reviews: bool = not p.review_results.is_empty()
		if not has_bugs and not has_reviews:
			continue
		var bugs_topic: bool = has_bugs
		if has_bugs and has_reviews:
			bugs_topic = ctx.rng.randi_range(0, 1) == 0
		add_forum_post(ctx, pid, &"forum.post.bugs" if bugs_topic else &"forum.post.weakness", ctx.tuning.forum_post_sentiment, false)


static func _tick_viral(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	var t: TuningDef = ctx.tuning
	for pid: int in state.sorted_ids(state.projects):
		var p: Project = state.projects[pid]
		if p.kind != Project.Kind.GAME or p.phase != Project.Phase.LIVE or not p.mod_tools:
			continue
		if not Fixed.roll_bp(ctx.rng, t.mod_viral_chance_bp):
			continue
		if state.companies.has(p.company_id):
			state.companies[p.company_id].fan_count += t.mod_viral_fans
		var extra: int = Fixed.mul_bp(p.sales_base_units, t.mod_viral_units_bp)
		if extra > 0 and not p.weekly_units.is_empty():
			p.weekly_units[-1] += extra
			SalesSystem.book_sale(ctx, p, extra, SalesSystem.unit_price(ctx.content, p, state.week))
		add_forum_post(ctx, pid, &"forum.post.mod_viral", t.mod_viral_sentiment, true)
