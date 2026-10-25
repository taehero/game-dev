class_name Removal
extends RefCounted
## The single deletion path for runtime entities (spec 4.8). Never touches RNG.
## Every removal also drops decisions whose related_ids mention the id, so saves stay valid.


static func remove_staff(state: GameState, staff_id: int) -> bool:
	if not state.staff.has(staff_id) or state.staff[staff_id].is_owner:
		return false
	state.staff.erase(staff_id)
	_drop_decisions_about(state, staff_id)
	return true


static func remove_equipment(state: GameState, equipment_id: int) -> bool:
	if not state.equipment.has(equipment_id):
		return false
	state.equipment.erase(equipment_id)
	_drop_decisions_about(state, equipment_id)
	return true


static func remove_contract(state: GameState, contract_id: int) -> bool:
	if not state.contracts.has(contract_id):
		return false
	for pid: int in state.sorted_ids(state.projects):
		if state.projects[pid].contract_id == contract_id:
			state.projects[pid].contract_id = -1
	state.contracts.erase(contract_id)
	_drop_decisions_about(state, contract_id)
	return true


static func remove_loan(state: GameState, loan_id: int) -> bool:
	if not state.loans.has(loan_id):
		return false
	state.loans.erase(loan_id)
	_drop_decisions_about(state, loan_id)
	return true


static func remove_candidate(state: GameState, candidate_id: int) -> bool:
	for i: int in state.candidates.size():
		if state.candidates[i].id == candidate_id:
			state.candidates.remove_at(i)
			_drop_decisions_about(state, candidate_id)
			return true
	return false


static func remove_decision(state: GameState, decision_id: int) -> bool:
	for i: int in state.pending_decisions.size():
		if state.pending_decisions[i].id == decision_id:
			state.pending_decisions.remove_at(i)
			_drop_decisions_about(state, decision_id)
			return true
	return false


static func _drop_decisions_about(state: GameState, id: int) -> void:
	var i: int = state.pending_decisions.size() - 1
	while i >= 0:
		if state.pending_decisions[i].related_ids.has(id):
			state.pending_decisions.remove_at(i)
		i -= 1
