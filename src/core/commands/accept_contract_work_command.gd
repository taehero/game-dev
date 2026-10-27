class_name AcceptContractWorkCommand
extends Command

var contract_id: int


func _init(p_contract_id: int) -> void:
	contract_id = p_contract_id


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	if not state.contracts.has(contract_id) or state.contracts[contract_id].kind != Contract.Kind.CONTRACT_WORK:
		return CommandResult.fail(&"error.contract_not_found")
	var c: Contract = state.contracts[contract_id]
	if c.project_id != -1:
		return CommandResult.fail(&"error.contract_taken")
	if state.week >= c.delivery_week or state.week >= c.deadline_week:
		return CommandResult.fail(&"error.contract_expired")
	if GameRules.free_workers(state, state.player_company_id).is_empty():
		return CommandResult.fail(&"error.not_enough_staff")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	var c: Contract = state.contracts[contract_id]
	var p := Project.new()
	p.id = state.alloc_id()
	p.company_id = state.player_company_id
	p.title = "ui.contract_work.title"
	p.kind = Project.Kind.CONTRACT_WORK
	p.phase = Project.Phase.PRODUCTION
	p.contract_id = contract_id
	p.deadline_week = c.deadline_week
	p.size_id = &""
	p.engine_id = -1
	for sid: int in GameRules.free_workers(state, state.player_company_id):
		state.staff[sid].assigned_project_id = p.id
	c.project_id = p.id
	state.projects[p.id] = p
	ctx.emit(&"project_phase_changed", {"project_id": p.id, "phase": "PRODUCTION"})
