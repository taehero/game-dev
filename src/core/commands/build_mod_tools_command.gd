class_name BuildModToolsCommand
extends Command

var project_id: int
var staff_ids: Array[int]


func _init(p_project_id: int, p_staff_ids: Array[int] = []) -> void:
	project_id = p_project_id
	staff_ids = p_staff_ids


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	var key: StringName = LiveOpsSystem.live_task_block_key(state, project_id)
	if key != &"":
		return CommandResult.fail(key)
	if state.projects[project_id].parent_id != -1:
		return CommandResult.fail(&"error.dlc_of_dlc")
	if state.projects[project_id].mod_tools:
		return CommandResult.fail(&"error.mod_tools_built")
	var sk: StringName = LiveOpsSystem.staff_choice_key(state, state.projects[project_id].company_id, staff_ids)
	if sk != &"":
		return CommandResult.fail(sk)
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	LiveOpsSystem.start_task(ctx, project_id, Project.LiveTask.MOD_TOOLS, ctx.tuning.mod_tools_staff_weeks, staff_ids)
