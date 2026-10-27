class_name ScenarioM2b
extends RefCounted
## Test helper: Scenario's loop plus the M2b money, people and contract-work specs.

const SCRIPT_M2B: Dictionary = {
	0: [["take_loan", "BANK", 5000]],
	4: [["hire_candidate"], ["buy_equipment", "equipment_micro_1980", 1], ["accept_contract_work"]],
	16: [["start_game", "Star Run", "size_small", "platform_nova8", "topic_space", "genre_action", "lic_engine_homebrew", []],
		["sliders_ideal"]],
	30: [["spend_skill_point", "perk_coder"]],
	36: [["release"]],
	40: [["repay_loan_all"]],
}


static func advance(state: GameState, script: Dictionary, weeks: int, content: ContentDB = null, tuning: TuningDef = null) -> void:
	if content != null:
		ContentDB.use(content)
	var session := GameSession.new(state, tuning if tuning != null else Fixtures.tuning())
	for i: int in weeks:
		if script.has(state.week):
			for spec: Array in script[state.week]:
				var cmd: Command = _make_command(state, spec)
				var result: CommandResult = session.submit(cmd)
				if not result.ok:
					push_error("ScenarioM2b: command %s rejected at week %d: %s" % [str(spec), state.week, result.reason_key])
					assert(false, "ScenarioM2b command rejected")
		session.step_once()


static func _make_command(state: GameState, spec: Array) -> Command:
	var pid: int = state.player_company_id
	match spec[0]:
		"take_loan":
			var kind: Company.Kind = Company.Kind.BANK if spec[1] == "BANK" else Company.Kind.LENDER
			for id: int in state.sorted_ids(state.companies):
				if state.companies[id].kind == kind:
					return TakeLoanCommand.new(pid, id, spec[2])
		"repay_loan_all":
			for id: int in state.sorted_ids(state.loans):
				if state.loans[id].company_id == pid:
					return RepayLoanCommand.new(id, state.loans[id].balance)
		"hire_candidate":
			var low: int = -1
			for c: Candidate in state.candidates:
				if low == -1 or c.id < low:
					low = c.id
			return HireCandidateCommand.new(pid, low)
		"buy_equipment":
			return BuyEquipmentCommand.new(pid, StringName(spec[1]), spec[2])
		"accept_contract_work":
			for id: int in state.sorted_ids(state.contracts):
				var c: Contract = state.contracts[id]
				if c.kind == Contract.Kind.CONTRACT_WORK and c.project_id == -1:
					return AcceptContractWorkCommand.new(id)
		"spend_skill_point":
			return SpendSkillPointCommand.new(StringName(spec[1]))
		"set_owner_focus":
			return SetOwnerFocusCommand.new(spec[1])
		_:
			return Scenario._make_command(state, spec)
	push_error("ScenarioM2b: no target for spec %s" % str(spec))
	assert(false, "ScenarioM2b no target")
	return null
