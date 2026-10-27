extends GutTest


func _run(s: GameState, id: StringName) -> CommandResult:
	var cmd := SignEngineLicenseCommand.new(s.player_company_id, id)
	var r: CommandResult = cmd.validate(s, Fixtures.tuning())
	if r.ok:
		cmd.apply(TickContext.new(s, Fixtures.tuning()))
	return r


func test_sign_license_unlocks_engine() -> void:
	var s := Fixtures.new_state(1)
	s.week = 5
	var co: Company = s.companies[s.player_company_id]
	co.money = 15000
	assert_true(_run(s, &"lic_engine_fx_pro").ok)
	assert_eq(co.money, 10000)
	var c: Contract = GameRules.engine_license_contract(s, s.player_company_id, &"lic_engine_fx_pro")
	assert_eq(c.kind, Contract.Kind.ENGINE_LICENSE)
	assert_eq(c.price, 5000)
	assert_eq(c.royalty_bp, 1000)
	assert_eq(s.companies[c.party_b].kind, Company.Kind.VENDOR)
	assert_true(GameRules.licensed_engine_available(s, Fixtures.content(), s.player_company_id, &"lic_engine_fx_pro", s.week, Fixtures.tuning()))


func test_license_rejections() -> void:
	var s := Fixtures.new_state(1)
	s.companies[s.player_company_id].money = 15000
	assert_eq(_run(s, &"lic_engine_homebrew").reason_key, &"error.license_not_needed")
	assert_eq(_run(s, &"nope").reason_key, &"error.engine_unavailable")
	assert_true(_run(s, &"lic_engine_fx_pro").ok)
	assert_eq(_run(s, &"lic_engine_fx_pro").reason_key, &"error.license_owned")
	var t := Fixtures.new_state(1)
	t.companies[t.player_company_id].money = 100
	assert_eq(_run(t, &"lic_engine_fx_pro").reason_key, &"error.not_enough_money")


func test_license_outside_year_range_unavailable() -> void:
	var s := Fixtures.new_state(1)
	s.companies[s.player_company_id].money = 15000
	s.week = 52 * 10
	assert_eq(_run(s, &"lic_engine_fx_pro").reason_key, &"error.engine_unavailable")


func test_license_without_vendor_fails() -> void:
	var s := Fixtures.new_state(1)
	s.companies[s.player_company_id].money = 15000
	for id: int in s.sorted_ids(s.companies):
		if s.companies[id].kind == Company.Kind.VENDOR:
			s.companies.erase(id)
	assert_eq(_run(s, &"lic_engine_fx_pro").reason_key, &"error.company_not_found")
