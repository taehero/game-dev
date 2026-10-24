extends GutTest


func _rt(s: GameState) -> Dictionary:
	return Fixtures.json_round_trip(s.to_dict())


func test_new_game_creates_player_company_with_start_money() -> void:
	var s := Fixtures.new_state(1)
	var c: Company = s.companies[s.player_company_id]
	assert_eq(c.kind, Company.Kind.PLAYER)
	assert_eq(c.money, 20000)


func test_alloc_id_is_unique_and_increasing() -> void:
	var s := Fixtures.new_state(1)
	var a := s.alloc_id()
	var b := s.alloc_id()
	assert_gt(b, a)


func test_staff_of_returns_sorted_ids_for_company() -> void:
	var s := Fixtures.new_state(1)
	var a := Fixtures.add_staff(s)
	var b := Fixtures.add_staff(s)
	assert_eq(s.staff_of(s.player_company_id), [a, b] as Array[int])
	assert_eq(s.staff_of(999), [] as Array[int])


func test_fixture_defaults_and_overrides() -> void:
	var s := Fixtures.new_state(1)
	var sid := Fixtures.add_staff(s, {"salary": 900})
	var pid := Fixtures.add_project(s)
	assert_eq(s.staff[sid].salary, 900)
	assert_eq(s.staff[sid].skills[&"tech"], 20)
	assert_eq(s.projects[pid].deadline_week, 24)
	assert_eq(s.projects[pid].company_id, s.player_company_id)


func test_64bit_seed_and_state_survive_round_trip() -> void:
	var s := Fixtures.new_state(9007199254740993)  # 2^53 + 1
	s.rng.randi()
	s.rng.randi()
	var d := _rt(s)
	assert_typeof(d["rng_state"], TYPE_STRING)
	var back := GameState.from_dict(d)
	assert_eq(back.rng_seed, 9007199254740993)
	assert_eq(back.rng.randi(), s.rng.randi())


func test_full_state_round_trip_preserves_hash() -> void:
	var s := Fixtures.new_state(5)
	Fixtures.add_staff(s)
	Fixtures.add_project(s)
	s.market.taste_bp[&"genre_rpg"] = 12346
	var back := GameState.from_dict(_rt(s))
	assert_eq(StateHash.of(back), StateHash.of(s))


func test_hash_ignores_dictionary_insertion_order() -> void:
	var a := Fixtures.new_state(5)
	var b := Fixtures.new_state(5)
	a.market.taste_bp[&"x"] = 10000
	a.market.taste_bp[&"y"] = 11000
	b.market.taste_bp[&"y"] = 11000
	b.market.taste_bp[&"x"] = 10000
	assert_eq(StateHash.of(a), StateHash.of(b))


func test_validate_rejects_dangling_company_id() -> void:
	var s := Fixtures.new_state(5)
	var sid := Fixtures.add_staff(s)
	var d := _rt(s)
	d["staff"][str(sid)]["company_id"] = 999
	assert_false(GameState.validate_dict(d))


func test_validate_rejects_unknown_enum_name() -> void:
	var d := _rt(Fixtures.new_state(5))
	d["companies"][str(int(d["player_company_id"]))]["kind"] = "GOD"
	assert_false(GameState.validate_dict(d))


func test_validate_rejects_next_id_not_above_used_ids() -> void:
	var d := _rt(Fixtures.new_state(5))
	d["next_id"] = 1
	assert_false(GameState.validate_dict(d))


func test_validate_accepts_valid_state() -> void:
	var s := Fixtures.new_state(5)
	Fixtures.add_staff(s)
	var pid := Fixtures.add_project(s, {"config": {&"genre": &"rpg"} as Dictionary[StringName, StringName]})
	s.market.focus_drift[&"rpg"] = [1, 2, 3]
	assert_true(pid > 0)
	assert_true(GameState.validate_dict(_rt(s)))


func test_validate_rejects_non_dictionary() -> void:
	assert_false(GameState.validate_dict("nope"))


func test_validate_rejects_unknown_project_phase() -> void:
	var s := Fixtures.new_state(5)
	var pid := Fixtures.add_project(s)
	var d := _rt(s)
	d["projects"][str(pid)]["phase"] = "NIRVANA"
	assert_false(GameState.validate_dict(d))


func test_validate_rejects_float_in_focus() -> void:
	var s := Fixtures.new_state(5)
	var pid := Fixtures.add_project(s)
	var d := _rt(s)
	d["projects"][str(pid)]["focus"][1] = 50.5
	assert_false(GameState.validate_dict(d))


func test_validate_rejects_wrong_focus_length() -> void:
	var s := Fixtures.new_state(5)
	var pid := Fixtures.add_project(s)
	var d := _rt(s)
	d["projects"][str(pid)]["focus"] = [1, 2]
	assert_false(GameState.validate_dict(d))


func test_validate_rejects_non_string_trait() -> void:
	var s := Fixtures.new_state(5)
	var sid := Fixtures.add_staff(s)
	var d := _rt(s)
	d["staff"][str(sid)]["traits"] = [7]
	assert_false(GameState.validate_dict(d))


func test_validate_rejects_non_numeric_rng_state() -> void:
	var d := _rt(Fixtures.new_state(5))
	d["rng_state"] = "abc"
	assert_false(GameState.validate_dict(d))


func test_validate_rejects_bad_market_drift() -> void:
	var s := Fixtures.new_state(5)
	s.market.focus_drift[&"rpg"] = [1, 2, 3]
	var d := _rt(s)
	d["market"]["focus_drift"]["rpg"] = [1, 2.5, 3]
	assert_false(GameState.validate_dict(d))


func test_validate_rejects_id_key_mismatch() -> void:
	var s := Fixtures.new_state(5)
	var sid := Fixtures.add_staff(s)
	var d := _rt(s)
	d["staff"][str(sid)]["id"] = sid + 1
	assert_false(GameState.validate_dict(d))


func test_validate_rejects_out_of_range_rng_seed() -> void:
	var d := _rt(Fixtures.new_state(5))
	d["rng_seed"] = "99999999999999999999999"
	assert_false(GameState.validate_dict(d))
	d["rng_seed"] = "+5"
	assert_false(GameState.validate_dict(d))


func test_from_dict_keeps_allocation_order() -> void:
	var s := Fixtures.new_state(5)
	for i in 11:
		Fixtures.add_staff(s)
	var back := GameState.from_dict(_rt(s))
	assert_eq(back.staff.keys(), s.staff.keys())
