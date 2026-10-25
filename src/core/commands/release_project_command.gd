class_name ReleaseProjectCommand
extends Command

var project_id: int


func _init(p_project_id: int) -> void:
	project_id = p_project_id


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	if not state.projects.has(project_id):
		return CommandResult.fail(&"error.project_not_found")
	var p: Project = state.projects[project_id]
	if p.kind != Project.Kind.GAME or p.phase != Project.Phase.POLISH:
		return CommandResult.fail(&"error.project_not_ready")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var p: Project = ctx.state.projects[project_id]
	p.phase = Project.Phase.RELEASED
	p.release_week = ctx.state.week
	ReviewSystem.review_project(ctx, project_id)
	for sid: int in ctx.state.sorted_ids(ctx.state.staff):
		var st: Staff = ctx.state.staff[sid]
		if st.assigned_project_id == project_id:
			st.assigned_project_id = -1
	ctx.emit(&"project_phase_changed", {"project_id": project_id, "phase": "RELEASED"})
