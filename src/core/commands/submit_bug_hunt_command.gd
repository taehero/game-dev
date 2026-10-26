class_name SubmitBugHuntCommand
extends Command

var project_id: int
var caught: int


func _init(p_project_id: int, p_caught: int) -> void:
	project_id = p_project_id
	caught = p_caught


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	if not state.projects.has(project_id):
		return CommandResult.fail(&"error.project_not_found")
	var p: Project = state.projects[project_id]
	if p.company_id != state.player_company_id:
		return CommandResult.fail(&"error.project_not_found")
	if p.kind != Project.Kind.GAME or p.phase != Project.Phase.POLISH:
		return CommandResult.fail(&"error.project_not_polishing")
	if p.bug_hunt_done:
		return CommandResult.fail(&"error.bug_hunt_done")
	if caught < 0:
		return CommandResult.fail(&"error.invalid_amount")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var p: Project = ctx.state.projects[project_id]
	var removed: int = mini(caught, mini(ctx.tuning.bug_hunt_max_bugs, p.bugs))
	p.bugs -= removed
	p.bug_hunt_done = true
	ctx.emit(&"project_changed", {"project_id": project_id, "bugs_removed": removed})
