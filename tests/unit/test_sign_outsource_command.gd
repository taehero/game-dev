extends GutTest


func _run(s: GameState, cmd: SignOutsourceCommand) -> CommandResult:
	var r: CommandResult = cmd.validate(s, Fixtures.tuning())
	if r.ok:
		cmd.apply(TickContext.new(s, Fixtures.tuning()))
	return r


func _vendor(s: GameState) -> int:
	return Fixtures.company_of_kind(s, Company.Kind.VENDOR)


func _contract(s: GameState) -> Contract:
	for id: int in s.sorted_ids(s.contracts):
		if s.contracts[id].kind == Contract.Kind.OUTSOURCE:
			return s.contracts[id]
	return null


func test_outsource_engine_price_and_delivery() -> void:
	var s := Fixtures.new_state(1)
	s.week = 10
	var co: Company = s.companies[s.player_company_id]
	co.money = 10000
	var feats: Array[StringName] = [&"feature_fx_save"]
	assert_true(_run(s, SignOutsourceCommand.engine(co.id, _vendor(s), feats)).ok)
	assert_eq(co.money, 7000)
	var c: Contract = _contract(s)
	assert_eq(c.price, 3000)
	assert_eq(c.deliverable, &"engine")
	assert_eq(c.features, feats)
	assert_between(c.delivery_week, 12, 16)
	assert_between(c.quality_roll, 0, 100)


func test_outsource_part_signs() -> void:
	var s := Fixtures.new_state(1)
	s.week = 4
	s.companies[s.player_company_id].money = 10000
	var pid: int = Fixtures.add_project(s, {"deadline_week": 30})
	assert_true(_run(s, SignOutsourceCommand.part(s.player_company_id, _vendor(s), pid, &"art")).ok)
	var c: Contract = _contract(s)
	assert_eq(c.price, 1500)
	assert_eq(c.project_id, pid)
	assert_eq(c.delivery_week, 30)
	assert_eq(c.target_points[&"art"], Fixed.mul_bp(Fixed.mul_bp(9000, 2500), 5000 + c.quality_roll * 100))
	assert_eq(_run(s, SignOutsourceCommand.part(s.player_company_id, _vendor(s), pid, &"art")).reason_key, &"error.already_outsourced")


func test_outsource_rejections() -> void:
	var s := Fixtures.new_state(1)
	var co: Company = s.companies[s.player_company_id]
	co.money = 10000
	var f1: Array[StringName] = [&"feature_fx_save"]
	assert_eq(_run(s, SignOutsourceCommand.engine(co.id, co.id, f1)).reason_key, &"error.vendor_not_found")
	var none: Array[StringName] = []
	assert_eq(_run(s, SignOutsourceCommand.engine(co.id, _vendor(s), none)).reason_key, &"error.no_features")
	var f2: Array[StringName] = [&"feature_fx_scroll"]
	assert_eq(_run(s, SignOutsourceCommand.engine(co.id, _vendor(s), f2)).reason_key, &"error.item_locked")
	var pid: int = Fixtures.add_project(s)
	assert_eq(_run(s, SignOutsourceCommand.part(co.id, _vendor(s), pid, &"tech")).reason_key, &"error.invalid_deliverable")
	assert_eq(_run(s, SignOutsourceCommand.part(co.id, _vendor(s), 999, &"art")).reason_key, &"error.project_not_found")
	s.projects[pid].phase = Project.Phase.POLISH
	assert_eq(_run(s, SignOutsourceCommand.part(co.id, _vendor(s), pid, &"art")).reason_key, &"error.project_not_in_production")
	co.money = 10
	assert_eq(_run(s, SignOutsourceCommand.engine(co.id, _vendor(s), f1)).reason_key, &"error.not_enough_money")
