extends GutTest

const TARGETS: Dictionary = {&"design": 100, &"tech": 100, &"art": 100, &"audio": 100}


func _tick(s: GameState, week: int) -> TickContext:
	s.week = week
	var ctx := TickContext.new(s, Fixtures.tuning())
	ContractsSystem.tick(ctx)
	return ctx


func _offered(s: GameState) -> Array[Contract]:
	var out: Array[Contract] = []
	for id: int in s.sorted_ids(s.contracts):
		out.append(s.contracts[id])
	return out


func _sum(c: Contract) -> int:
	var n: int = 0
	for k: StringName in c.target_points:
		n += c.target_points[k]
	return n


func _job(s: GameState, extra: Dictionary = {}) -> Array:
	var o: Dictionary = {"deadline_week": 12, "delivery_week": 8, "price": 1000, "target_points": TARGETS}
	o.merge(extra, true)
	var cid: int = Fixtures.add_contract(s, o)
	s.week = 4
	var cmd := AcceptContractWorkCommand.new(cid)
	assert_true(cmd.validate(s, Fixtures.tuning()).ok)
	cmd.apply(TickContext.new(s, Fixtures.tuning()))
	return [cid, s.contracts[cid].project_id]


func test_month_start_offers() -> void:
	var s := Fixtures.new_state(1)
	var ctx := _tick(s, 4)
	var offers := _offered(s)
	assert_eq(offers.size(), 2)
	for c: Contract in offers:
		assert_eq(s.companies[c.party_b].kind, Company.Kind.AI_PUBLISHER)
		for k: StringName in c.target_points:
			assert_between(c.target_points[k], 150, 500)
		assert_between(c.deadline_week, 4 + 6, 4 + 12)
		assert_eq(c.delivery_week, 8)
		assert_eq(c.price, _sum(c) * 3)
		assert_eq(c.project_id, -1)
	var n: int = 0
	for e: Dictionary in ctx.events:
		if e["name"] == &"contract_offered":
			n += 1
	assert_eq(n, 2)
	_tick(s, 5)
	assert_eq(s.contracts.size(), 2)


func test_negotiator_raises_offer_price() -> void:
	var s := Fixtures.new_state(1)
	s.owner.perks[&"perk_negotiator"] = 1
	s.owner.focus_dev_bp = 0
	_tick(s, 4)
	for c: Contract in _offered(s):
		assert_eq(c.price, Fixed.mul_bp(_sum(c) * 3, 11000))


func test_unaccepted_offer_expires() -> void:
	var s := Fixtures.new_state(1)
	_tick(s, 4)
	_tick(s, 7)
	assert_eq(s.contracts.size(), 2)
	_tick(s, 8)  # week 8 is a month start, so two fresh offers replace them
	for c: Contract in _offered(s):
		assert_eq(c.delivery_week, 12)


func test_met_target_pays_full() -> void:
	var s := Fixtures.new_state(1)
	var r := _job(s)
	var p: Project = s.projects[r[1]]
	for k: StringName in TARGETS:
		p.points[k] = 100
	var m: int = s.companies[s.player_company_id].money
	var ctx := _tick(s, 6)
	assert_eq(s.companies[s.player_company_id].money, m + 1000)
	assert_eq(p.phase, Project.Phase.RETIRED)
	assert_eq(p.revenue, 1000)
	assert_eq(s.staff[s.owner_staff_id()].assigned_project_id, -1)
	assert_true(s.contracts.has(r[0]))
	var met: bool = false
	for e: Dictionary in ctx.events:
		if e["name"] == &"contract_completed":
			met = e["payload"]["met"]
	assert_true(met)
	assert_true(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))


func test_missed_deadline_pays_half() -> void:
	var s := Fixtures.new_state(1)
	var r := _job(s)
	var company: Company = s.companies[s.player_company_id]
	company.reputation = 10
	var m: int = company.money
	_tick(s, 11)
	assert_eq(s.projects[r[1]].phase, Project.Phase.PRODUCTION)
	_tick(s, 12)
	assert_eq(company.money, m + 500)
	assert_eq(company.reputation, 7)
	assert_eq(s.projects[r[1]].revenue, 500)


func test_fired_worker_stalls_job_then_half_pay() -> void:
	var s := Fixtures.new_state(1)
	var w: int = Fixtures.add_worker(s)
	var other := Fixtures.add_project(s)
	s.staff[s.owner_staff_id()].assigned_project_id = other
	var r := _job(s)
	assert_eq(s.staff[w].assigned_project_id, r[1])
	var cmd := FireStaffCommand.new(w)
	cmd.apply(TickContext.new(s, Fixtures.tuning()))
	var m: int = s.companies[s.player_company_id].money
	for wk: int in range(5, 12):
		ProductionSystem.tick(TickContext.new(s, Fixtures.tuning()))
		_tick(s, wk)
	assert_eq(s.projects[r[1]].phase, Project.Phase.PRODUCTION)
	_tick(s, 12)
	assert_eq(s.projects[r[1]].phase, Project.Phase.RETIRED)
	assert_eq(s.companies[s.player_company_id].money, m + 500)
	assert_true(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))
