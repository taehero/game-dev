class_name BuildModToolsCommand
extends Command

var project_id: int


func _init(p_project_id: int) -> void:
	project_id = p_project_id


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	var key: StringName = LiveOpsSystem.live_task_block_key(state, project_id)
	if key != &"":
		return CommandResult.fail(key)
	if state.projects[project_id].mod_tools:
		return CommandResult.fail(&"error.mod_tools_built")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	LiveOpsSystem.start_task(ctx, project_id, Project.LiveTask.MOD_TOOLS, ctx.tuning.mod_tools_staff_weeks)
