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
