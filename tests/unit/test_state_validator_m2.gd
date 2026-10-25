extends GutTest


func _dict_with_staff() -> Array:
	var s := Fixtures.new_state(5)
	var sid := Fixtures.add_staff(s)
	return [Fixtures.json_round_trip(s.to_dict()), str(sid)]


func test_accepts_default_state_with_new_fields() -> void:
	var x := _dict_with_staff()
	assert_true(GameState.validate_dict(x[0]))


func test_rejects_unknown_staff_level() -> void:
	var x := _dict_with_staff()
	x[0]["staff"][x[1]]["level"] = "CEO"
	assert_false(GameState.validate_dict(x[0]))


func test_rejects_exp_key_outside_skills() -> void:
	var x := _dict_with_staff()
	x[0]["staff"][x[1]]["exp"]["luck"] = 5
	assert_false(GameState.validate_dict(x[0]))


func test_rejects_fractional_week_points() -> void:
	var x := _dict_with_staff()
	x[0]["staff"][x[1]]["week_points"]["art"] = 1.5
	assert_false(GameState.validate_dict(x[0]))


func test_rejects_negative_exp_and_seat_below_minus_one() -> void:
	var x := _dict_with_staff()
	x[0]["staff"][x[1]]["exp"]["art"] = -1
	assert_false(GameState.validate_dict(x[0]))
	var y := _dict_with_staff()
	y[0]["staff"][y[1]]["seat_index"] = -2
	assert_false(GameState.validate_dict(y[0]))


func test_rejects_bad_company_fields() -> void:
	var s := Fixtures.new_state(5)
	var cid: String = str(s.player_company_id)
	var d: Dictionary = Fixtures.json_round_trip(s.to_dict())
	d["companies"][cid]["unlocked"] = [5]
	assert_false(GameState.validate_dict(d))
	d = Fixtures.json_round_trip(s.to_dict())
	d["companies"][cid]["months_negative"] = -1
	assert_false(GameState.validate_dict(d))
	d = Fixtures.json_round_trip(s.to_dict())
	d["companies"][cid]["research_points"] = 1.5
	assert_false(GameState.validate_dict(d))
	d = Fixtures.json_round_trip(s.to_dict())
	d["companies"][cid]["kind"] = "NOPE"
	assert_false(GameState.validate_dict(d))


func test_rejects_contract_with_dangling_project() -> void:
	var s := Fixtures.new_state(5)
	var c := Contract.new()
	c.id = s.alloc_id()
	c.party_a = s.player_company_id
	c.party_b = s.player_company_id
	c.project_id = 999
	s.contracts[c.id] = c
	assert_false(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))


func test_rejects_quality_roll_above_100() -> void:
	var s := Fixtures.new_state(5)
	var c := Contract.new()
	c.id = s.alloc_id()
	c.party_a = s.player_company_id
	c.party_b = s.player_company_id
	c.quality_roll = 101
	s.contracts[c.id] = c
	assert_false(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))


func test_rejects_contract_target_points_bad_key() -> void:
	var s := Fixtures.new_state(5)
	var c := Contract.new()
	c.id = s.alloc_id()
	c.party_a = s.player_company_id
	c.party_b = s.player_company_id
	s.contracts[c.id] = c
	var d: Dictionary = Fixtures.json_round_trip(s.to_dict())
	assert_true(GameState.validate_dict(d))
	d["contracts"][str(c.id)]["target_points"]["luck"] = 3
	assert_false(GameState.validate_dict(d))


func _project_dict() -> Array:
	var s := Fixtures.new_state(5)
	var pid := Fixtures.add_project(s)
	return [Fixtures.json_round_trip(s.to_dict()), str(pid)]


func test_accepts_default_project() -> void:
	assert_true(GameState.validate_dict(_project_dict()[0]))


func test_rejects_stage_not_summing_to_10000() -> void:
	var x := _project_dict(); x[0]["projects"][x[1]]["focus"][0] = 3333
	assert_false(GameState.validate_dict(x[0]))


func test_rejects_weekly_units_over_cap() -> void:
	var x := _project_dict()
	var a: Array = []; a.resize(105); a.fill(1)
	x[0]["projects"][x[1]]["weekly_units"] = a
	assert_false(GameState.validate_dict(x[0]))


func test_rejects_review_score_out_of_range() -> void:
	var x := _project_dict()
	x[0]["projects"][x[1]]["review_results"] = [{"outlet_id": "o", "score_x10": 101, "strength_key": "a", "weakness_key": "b"}]
	assert_false(GameState.validate_dict(x[0]))


func test_rejects_unknown_project_kind() -> void:
	var x := _project_dict(); x[0]["projects"][x[1]]["kind"] = "MOVIE"
	assert_false(GameState.validate_dict(x[0]))


func test_rejects_owner_pointing_at_non_owner_staff() -> void:
	var s := Fixtures.new_state(5)
	var sid := Fixtures.add_staff(s)
	var d := Fixtures.json_round_trip(s.to_dict())
	d["owner"]["staff_id"] = sid
	assert_false(GameState.validate_dict(d))


func test_rejects_two_staff_in_one_seat() -> void:
	var s := Fixtures.new_state(5)
	Fixtures.add_staff(s, {"seat_index": 0})
	assert_false(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))


func test_rejects_loan_from_non_lender() -> void:
	var s := Fixtures.new_state(5)
	var l := Loan.new()
	l.id = s.alloc_id()
	l.company_id = s.player_company_id
	l.lender_id = 8  # publisher
	s.loans[l.id] = l
	assert_false(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))


func test_rejects_dangling_engine_id() -> void:
	var s := Fixtures.new_state(5)
	Fixtures.add_project(s, {"engine_id": 999})
	assert_false(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))


func test_rejects_equipment_of_unknown_company() -> void:
	var s := Fixtures.new_state(5)
	var eid := Fixtures.add_equipment(s)
	var d := Fixtures.json_round_trip(s.to_dict())
	d["equipment"][str(eid)]["company_id"] = 999
	assert_false(GameState.validate_dict(d))
