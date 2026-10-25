class_name SetSlidersCommand
extends Command

var project_id: int
var focus: Array[int]


func _init(p_project_id: int, p_focus: Array[int]) -> void:
	project_id = p_project_id
	focus = p_focus.duplicate()


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	if not state.projects.has(project_id):
		return CommandResult.fail(&"error.project_not_found")
	var p: Project = state.projects[project_id]
	if p.kind != Project.Kind.GAME or p.phase != Project.Phase.PRODUCTION:
		return CommandResult.fail(&"error.project_not_in_production")
	if focus.size() != 9:
		return CommandResult.fail(&"error.invalid_sliders")
	for v: int in focus:
		if v < 0 or v > Fixed.ONE_BP:
			return CommandResult.fail(&"error.invalid_sliders")
	for stage: int in 3:
		if not GameRules.stage_sliders_ok(focus, stage):
			return CommandResult.fail(&"error.invalid_sliders")
	for i: int in mini(p.stage_index, 3) * 3:
		if focus[i] != p.focus[i]:
			return CommandResult.fail(&"error.past_stage_locked")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var p: Project = ctx.state.projects[project_id]
	p.focus = focus.duplicate()
	ctx.emit(&"project_changed", {"project_id": project_id})
