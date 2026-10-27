extends GutTest


func _state() -> GameState:
	return Fixtures.new_state(11)


func test_new_fields_round_trip() -> void:
	var s := _state()
	var sid := Fixtures.add_staff(s, {"raise_refusals": 2})
	s.companies[s.player_company_id].last_missed_week = 30
	var cid := Fixtures.add_contract(s, {"kind": Contract.Kind.OUTSOURCE, "features": [&"feature_fx_save"]})
	var d := Fixtures.json_round_trip(s.to_dict())
	assert_true(GameState.validate_dict(d))
	var s2 := GameState.from_dict(d)
	assert_eq(s2.staff[sid].raise_refusals, 2)
	assert_eq(s2.companies[s2.player_company_id].last_missed_week, 30)
	assert_eq(s2.contracts[cid].features, [&"feature_fx_save"] as Array[StringName])
	assert_eq(StateHash.of(s2), StateHash.of(s))


func test_rejects_bad_m2b_values() -> void:
	var s := _state()
	var sid := Fixtures.add_staff(s)
	var cid := Fixtures.add_contract(s)
	var lid := Fixtures.add_loan(s)
	var eid := Fixtures.add_equipment(s)
	var edits: Array[Callable] = [
		func(d: Dictionary) -> void: d["staff"][str(sid)]["raise_refusals"] = -1,
		func(d: Dictionary) -> void: d["companies"][str(s.player_company_id)]["last_missed_week"] = -2,
		func(d: Dictionary) -> void: d["contracts"][str(cid)]["features"] = [3],
		func(d: Dictionary) -> void: d["loans"][str(lid)]["balance"] = -1,
		func(d: Dictionary) -> void: d["loans"][str(lid)]["principal"] = -1,
		func(d: Dictionary) -> void: d["loans"][str(lid)]["rate_bp_per_month"] = -1,
		func(d: Dictionary) -> void: d["loans"][str(lid)]["payment_per_month"] = -1,
		func(d: Dictionary) -> void: d["loans"][str(lid)]["missed_payments"] = -1,
		func(d: Dictionary) -> void: d["equipment"][str(eid)]["value"] = -1,
	]
	for edit: Callable in edits:
		var d := Fixtures.json_round_trip(s.to_dict())
		assert_true(GameState.validate_dict(d))
		edit.call(d)
		assert_false(GameState.validate_dict(d))


func test_missing_refs_reports_contract_feature() -> void:
	var s := _state()
	Fixtures.add_contract(s, {"features": [&"feature_gone"]})
	var refs: Array[String] = Fixtures.content().missing_refs(s)
	assert_eq(refs.size(), 1)
	assert_string_contains(refs[0], "feature_gone")


func test_known_contract_feature_has_no_missing_ref() -> void:
	var s := _state()
	Fixtures.add_contract(s, {"features": [&"feature_fx_save"]})
	assert_eq(Fixtures.content().missing_refs(s).size(), 0)


func test_fixture_perks_and_future_equipment() -> void:
	assert_eq(Fixtures.content().perks.size(), 7)
	assert_eq(Fixtures.content().equipment[&"equipment_fx_future"].year_from, 1990)


func test_fixture_helpers() -> void:
	var s := _state()
	assert_eq(Fixtures.company_of_kind(s, Company.Kind.BANK), s.companies.keys().filter(func(i: int) -> bool: return s.companies[i].kind == Company.Kind.BANK).min())
	var lid := Fixtures.add_loan(s)
	assert_eq(s.loans[lid].payment_per_month, 209)


func test_contract_party_b_and_absent_kind() -> void:
	var s := _state()
	var cid := Fixtures.add_contract(s)
	assert_eq(s.companies[s.contracts[cid].party_b].kind, Company.Kind.AI_PUBLISHER)
	for id: int in s.companies.keys():
		if s.companies[id].kind == Company.Kind.BANK:
			s.companies.erase(id)
	assert_eq(Fixtures.company_of_kind(s, Company.Kind.BANK), -1)
