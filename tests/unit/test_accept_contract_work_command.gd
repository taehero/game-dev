extends GutTest


func _setup() -> Array:
	var s := Fixtures.new_state(1)
	s.week = 4
	var cid: int = Fixtures.add_contract(s, {"deadline_week": 12, "delivery_week": 8, "price": 1000,
		"target_points": {&"design": 100, &"tech": 100, &"art": 100, &"audio": 100}})
	return [s, cid]


func _apply(s: GameState, cmd: AcceptContractWorkCommand) -> void:
	cmd.apply(TickContext.new(s, Fixtures.tuning()))


func test_accept_creates_project() -> void:
	var r := _setup()
	var s: GameState = r[0]
	var owner_id: int = s.owner_staff_id()
	var cmd := AcceptContractWorkCommand.new(r[1])
	assert_true(cmd.validate(s, Fixtures.tuning()).ok)
	_apply(s, cmd)
	var c: Contract = s.contracts[r[1]]
	assert_ne(c.project_id, -1)
	var p: Project = s.projects[c.project_id]
	assert_eq(p.kind, Project.Kind.CONTRACT_WORK)
	assert_eq(p.phase, Project.Phase.PRODUCTION)
	assert_eq(p.contract_id, r[1])
	assert_eq(p.deadline_week, 12)
	assert_eq(s.staff[owner_id].assigned_project_id, p.id)
	assert_true(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))


func test_accept_rejections() -> void:
	var r := _setup()
	var s: GameState = r[0]
	var t := Fixtures.tuning()
	assert_eq(AcceptContractWorkCommand.new(9999).validate(s, t).reason_key, &"error.contract_not_found")
	var g: int = Fixtures.add_contract(s, {"kind": Contract.Kind.OUTSOURCE})
	assert_eq(AcceptContractWorkCommand.new(g).validate(s, t).reason_key, &"error.contract_not_found")
	s.week = 8
	assert_eq(AcceptContractWorkCommand.new(r[1]).validate(s, t).reason_key, &"error.contract_expired")
	s.week = 4
	for sid: int in s.sorted_ids(s.staff):
		s.staff[sid].assigned_project_id = 999
	assert_eq(AcceptContractWorkCommand.new(r[1]).validate(s, t).reason_key, &"error.not_enough_staff")
	for sid: int in s.sorted_ids(s.staff):
		s.staff[sid].assigned_project_id = -1
	s.contracts[r[1]].project_id = 5
	assert_eq(AcceptContractWorkCommand.new(r[1]).validate(s, t).reason_key, &"error.contract_taken")
