extends GutTest

func _valid(s: GameState) -> bool:
	return GameState.validate_dict(Fixtures.json_round_trip(s.to_dict()))

func _decision_about(s: GameState, id: int) -> int:
	var d := Decision.new()
	d.id = s.alloc_id()
	d.kind = &"test"
	d.related_ids = [id]
	s.pending_decisions.append(d)
	return d.id

func test_remove_staff_frees_seat_and_drops_decisions() -> void:
	var s := Fixtures.new_state(1)
	var sid := Fixtures.add_worker(s)
	_decision_about(s, sid)
	assert_true(Removal.remove_staff(s, sid))
	assert_false(s.staff.has(sid))
	assert_eq(s.pending_decisions.size(), 0)
	assert_true(_valid(s))

func test_owner_cannot_be_removed() -> void:
	var s := Fixtures.new_state(1)
	assert_false(Removal.remove_staff(s, s.owner_staff_id()))
	assert_true(s.staff.has(s.owner_staff_id()))

func test_remove_contract_clears_project_reference() -> void:
	var s := Fixtures.new_state(1)
	var c := Contract.new()
	c.id = s.alloc_id()
	c.party_a = 1
	c.party_b = 8
	s.contracts[c.id] = c
	var pid := Fixtures.add_project(s, {"contract_id": c.id})
	_decision_about(s, c.id)
	assert_true(Removal.remove_contract(s, c.id))
	assert_eq(s.pending_decisions.size(), 0)
	assert_eq(s.projects[pid].contract_id, -1)
	assert_true(_valid(s))

func test_remove_equipment_loan_candidate_decision_keep_state_valid() -> void:
	var s := Fixtures.new_state(1)
	var eid := Fixtures.add_equipment(s, {"seat_index": 1})
	var l := Loan.new()
	l.id = s.alloc_id()
	l.company_id = 1
	l.lender_id = 4
	s.loans[l.id] = l
	var c := Candidate.new()
	c.id = s.alloc_id()
	c.skills = {&"art": 1, &"audio": 1, &"design": 1, &"tech": 1}
	s.candidates.append(c)
	var did := _decision_about(s, c.id)
	_decision_about(s, eid)
	assert_true(Removal.remove_equipment(s, eid))
	assert_eq(s.pending_decisions.size(), 1)
	assert_true(_valid(s))
	_decision_about(s, l.id)
	assert_true(Removal.remove_loan(s, l.id))
	assert_eq(s.pending_decisions.size(), 1)
	assert_true(_valid(s))
	assert_true(Removal.remove_candidate(s, c.id))
	assert_true(_valid(s))
	assert_false(s.pending_decisions.any(func(d: Decision) -> bool: return d.id == did))
	assert_false(Removal.remove_decision(s, did))

func test_unknown_id_returns_false() -> void:
	assert_false(Removal.remove_loan(Fixtures.new_state(1), 999))

func test_remove_decision_drops_decisions_that_reference_it() -> void:
	var s := Fixtures.new_state(1)
	var first := _decision_about(s, s.owner_staff_id())
	var second := _decision_about(s, first)
	var third := _decision_about(s, s.owner_staff_id())
	assert_true(Removal.remove_decision(s, first))
	assert_eq(s.pending_decisions.size(), 1)
	assert_eq(s.pending_decisions[0].id, third)
	assert_false(s.pending_decisions.any(func(d: Decision) -> bool: return d.id == second))
	assert_true(_valid(s))


func test_remove_decision_cascades_through_two_levels() -> void:
	var s := Fixtures.new_state(1)
	var a := _decision_about(s, s.owner_staff_id())
	var b := _decision_about(s, a)
	var c := _decision_about(s, b)
	var keep := _decision_about(s, s.owner_staff_id())
	assert_true(Removal.remove_decision(s, a))
	assert_eq(s.pending_decisions.size(), 1)
	assert_eq(s.pending_decisions[0].id, keep)
	assert_false(s.pending_decisions.any(func(d: Decision) -> bool: return d.id == b or d.id == c))
	assert_true(_valid(s))
