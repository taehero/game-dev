class_name StartDLCCommand
extends Command

var parent_id: int
var title: String


func _init(p_parent_id: int, p_title: String) -> void:
	parent_id = p_parent_id
	title = p_title


func validate(state: GameState, tuning: TuningDef) -> CommandResult:
	if not state.projects.has(parent_id):
		return CommandResult.fail(&"error.project_not_found")
	if title.strip_edges().is_empty():
		return CommandResult.fail(&"error.title_empty")
	var parent: Project = state.projects[parent_id]
	if parent.parent_id != -1:
		return CommandResult.fail(&"error.dlc_of_dlc")
	if parent.kind != Project.Kind.GAME or parent.phase != Project.Phase.LIVE:
		return CommandResult.fail(&"error.project_not_live")
	var content: ContentDB = ContentDB.active()
	if not content.sizes.has(tuning.dlc_size_id):
		return CommandResult.fail(&"error.size_not_found")
	for pid: int in state.sorted_ids(state.projects):
		var o: Project = state.projects[pid]
		if o.parent_id == parent_id and (o.phase == Project.Phase.PRODUCTION or o.phase == Project.Phase.POLISH):
			return CommandResult.fail(&"error.dlc_in_progress")
	if GameRules.free_workers(state, parent.company_id).size() < content.sizes[tuning.dlc_size_id].min_staff:
		return CommandResult.fail(&"error.not_enough_staff")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var parent: Project = ctx.state.projects[parent_id]
	var p := Project.new()
	p.id = ctx.state.alloc_id()
	p.company_id = parent.company_id
	p.title = title
	p.kind = Project.Kind.GAME
	p.parent_id = parent_id
	p.size_id = ctx.tuning.dlc_size_id
	p.phase = Project.Phase.PRODUCTION
	for k: StringName in GameState.sorted_names(parent.config):
		p.config[k] = parent.config[k]
	p.engine_id = parent.engine_id
	p.features = parent.features.duplicate()
	p.focus = Project.DEFAULT_FOCUS.duplicate()
	p.deadline_week = ctx.state.week + GameRules.stage_count(p) * GameRules.stage_weeks(p, ctx.content, ctx.tuning)
	for sid: int in GameRules.free_workers(ctx.state, p.company_id):
		ctx.state.staff[sid].assigned_project_id = p.id
	ctx.state.projects[p.id] = p
	parent.dlc_count += 1
	ctx.emit(&"project_phase_changed", {"project_id": p.id, "phase": "PRODUCTION"})
