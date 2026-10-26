class_name ChooseEventOptionCommand
extends Command

var decision_id: int
var option_index: int


func _init(p_decision_id: int, p_option_index: int) -> void:
	decision_id = p_decision_id
	option_index = p_option_index


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	var d: Decision = _find(state)
	if d == null:
		return CommandResult.fail(&"error.decision_not_found")
	if not ProductionEventSystem.is_event_decision(ContentDB.active(), d):
		return CommandResult.fail(&"error.decision_not_event")
	if option_index < 0 or option_index >= d.option_keys.size():
		return CommandResult.fail(&"error.invalid_option")
	if d.related_ids.is_empty() or not state.projects.has(d.related_ids[0]):
		return CommandResult.fail(&"error.project_not_found")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var d: Decision = _find(ctx.state)
	var project_id: int = d.related_ids[0]
	ProductionEventSystem.apply_effects(ctx, ctx.content.production_events[d.kind], option_index, project_id)
	Removal.remove_decision(ctx.state, decision_id)
	ctx.emit(&"project_changed", {"project_id": project_id})


func _find(state: GameState) -> Decision:
	for d: Decision in state.pending_decisions:
		if d.id == decision_id:
			return d
	return null
