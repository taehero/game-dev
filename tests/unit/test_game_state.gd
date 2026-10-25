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
	assert_eq(s.staff_of(s.player_company_id), [s.owner_staff_id(), a, b] as Array[int])
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
	Fixtures.add_project(s, {"config": {&"genre": &"rpg"} as Dictionary[StringName, StringName]})
	s.market.focus_drift[&"rpg"] = [1, 2, 3]
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
	d["projects"][str(pid)]["focus"] = [1, 2, 3]
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
	for i: int in 11:
		Fixtures.add_staff(s)
	var back := GameState.from_dict(_rt(s))
	assert_eq(back.staff.keys(), s.staff.keys())


func test_validate_rejects_non_canonical_entity_keys() -> void:
	for bad_key: String in ["02", "+2", "99999999999999999999999"]:
		var s := Fixtures.new_state(5)
		var sid := Fixtures.add_staff(s)
		var d := _rt(s)
		var e: Dictionary = d["staff"][str(sid)]
		d["staff"].erase(str(sid))
		d["staff"][bad_key] = e
		assert_false(GameState.validate_dict(d), "key %s" % bad_key)


func test_validate_rejects_non_canonical_rng_strings() -> void:
	for field: String in ["rng_seed", "rng_state"]:
		for bad: String in ["-0", "007", "+5", "99999999999999999999999", ""]:
			var d := _rt(Fixtures.new_state(5))
			d[field] = bad
			assert_false(GameState.validate_dict(d), "%s=%s" % [field, bad])


func test_sorted_names_orders_by_string_value() -> void:
	var s := Fixtures.new_state(1)
	var d: Dictionary = {&"tech": 1, &"art": 2, &"design": 3, &"audio": 4}
	assert_eq(s.sorted_names(d), [&"art", &"audio", &"design", &"tech"] as Array[StringName])


func test_hired_staff_skill_order_survives_round_trip() -> void:
	var s := Fixtures.new_state(3)
	var t := Fixtures.tuning()
	HireStaffCommand.new(s.player_company_id, "Ada", 800).apply(TickContext.new(s, t))
	var back := GameState.from_dict(_rt(s))
	var live: Staff = s.staff[s.next_id - 1]
	var loaded: Staff = back.staff[s.next_id - 1]
	assert_eq(loaded.skills.keys(), live.skills.keys())
	assert_eq(live.skills.keys(), [&"art", &"audio", &"design", &"tech"])


func test_project_and_market_key_order_survives_round_trip() -> void:
	var s := Fixtures.new_state(3)
	var pid := Fixtures.add_project(s, {
		"config": {&"genre": &"rpg", &"engine": &"e1", &"art_style": &"px"} as Dictionary[StringName, StringName],
		"points": {&"tech": 1, &"design": 2, &"art": 3} as Dictionary[StringName, int],
	})
	s.market.taste_bp[&"z"] = 1
	s.market.taste_bp[&"a"] = 2
	var back := GameState.from_dict(_rt(s))
	assert_eq(back.projects[pid].config.keys(), [&"art_style", &"engine", &"genre"])
	assert_eq(back.projects[pid].points.keys(), [&"art", &"design", &"tech"])
	assert_eq(back.market.taste_bp.keys(), [&"a", &"z"])


# ---- validator reference integrity ----

func _valid_with_everything() -> GameState:
	var s := Fixtures.new_state(5)
	Fixtures.add_staff(s)
	Fixtures.add_project(s)
	return s


func test_validate_rejects_missing_player_company() -> void:
	var d := _rt(Fixtures.new_state(5))
	d["player_company_id"] = 999
	assert_false(GameState.validate_dict(d))


func test_validate_rejects_project_with_unknown_company() -> void:
	var s := Fixtures.new_state(5)
	var pid := Fixtures.add_project(s)
	var d := _rt(s)
	d["projects"][str(pid)]["company_id"] = 999
	assert_false(GameState.validate_dict(d))


func test_validate_rejects_staff_assigned_to_unknown_project() -> void:
	var s := Fixtures.new_state(5)
	var sid := Fixtures.add_staff(s)
	var d := _rt(s)
	d["staff"][str(sid)]["assigned_project_id"] = 999
	assert_false(GameState.validate_dict(d))


func _add_contract(s: GameState) -> int:
	var c := Contract.new()
	c.id = s.alloc_id()
	c.party_a = s.player_company_id
	c.party_b = s.player_company_id
	s.contracts[c.id] = c
	return c.id


func test_validate_rejects_contract_with_unknown_party() -> void:
	for field: String in ["party_a", "party_b"]:
		var s := Fixtures.new_state(5)
		var cid := _add_contract(s)
		var d := _rt(s)
		assert_true(GameState.validate_dict(d), "baseline")
		d["contracts"][str(cid)][field] = 999
		assert_false(GameState.validate_dict(d), field)


func test_validate_rejects_project_with_unknown_contract() -> void:
	var s := Fixtures.new_state(5)
	var pid := Fixtures.add_project(s)
	var d := _rt(s)
	d["projects"][str(pid)]["contract_id"] = 999
	assert_false(GameState.validate_dict(d))


func test_validate_accepts_project_with_existing_contract() -> void:
	var s := Fixtures.new_state(5)
	var cid := _add_contract(s)
	Fixtures.add_project(s, {"contract_id": cid})
	assert_true(GameState.validate_dict(_rt(s)))


func _add_post(s: GameState, project_id: int) -> int:
	var f := ForumPost.new()
	f.id = s.alloc_id()
	f.project_id = project_id
	s.forum_posts.append(f)
	return f.id


func test_validate_rejects_forum_post_with_unknown_project() -> void:
	var s := Fixtures.new_state(5)
	var pid := Fixtures.add_project(s)
	_add_post(s, pid)
	var d := _rt(s)
	assert_true(GameState.validate_dict(d), "baseline")
	d["forum_posts"][0]["project_id"] = 999
	assert_false(GameState.validate_dict(d))


func _add_decision(s: GameState, related: Array[int]) -> int:
	var dec := Decision.new()
	dec.id = s.alloc_id()
	dec.related_ids = related
	s.pending_decisions.append(dec)
	return dec.id


func test_validate_rejects_decision_with_unknown_related_id() -> void:
	var s := Fixtures.new_state(5)
	var sid := Fixtures.add_staff(s)
	_add_decision(s, [sid] as Array[int])
	var d := _rt(s)
	assert_true(GameState.validate_dict(d), "baseline")
	d["pending_decisions"][0]["related_ids"] = [sid, 999]
	assert_false(GameState.validate_dict(d))


func test_validate_rejects_duplicate_id_across_categories() -> void:
	var s := Fixtures.new_state(5)
	var sid := Fixtures.add_staff(s)
	var pid := Fixtures.add_project(s)
	var d := _rt(s)
	var e: Dictionary = d["projects"][str(pid)]
	d["projects"].erase(str(pid))
	e["id"] = sid
	d["projects"][str(sid)] = e
	assert_false(GameState.validate_dict(d))


func test_validate_rejects_duplicate_ids_within_lists() -> void:
	var s := Fixtures.new_state(5)
	var pid := Fixtures.add_project(s)
	_add_post(s, pid)
	_add_post(s, pid)
	var d := _rt(s)
	assert_true(GameState.validate_dict(d), "baseline")
	d["forum_posts"][1]["id"] = d["forum_posts"][0]["id"]
	assert_false(GameState.validate_dict(d), "forum_posts")
	var s2 := Fixtures.new_state(5)
	_add_decision(s2, [] as Array[int])
	_add_decision(s2, [] as Array[int])
	var d2 := _rt(s2)
	assert_true(GameState.validate_dict(d2), "baseline")
	d2["pending_decisions"][1]["id"] = d2["pending_decisions"][0]["id"]
	assert_false(GameState.validate_dict(d2), "pending_decisions")


func test_validate_rejects_non_positive_entity_ids() -> void:
	for bad: int in [0, -3]:
		var s := Fixtures.new_state(5)
		var sid := Fixtures.add_staff(s)
		var d := _rt(s)
		var e: Dictionary = d["staff"][str(sid)]
		d["staff"].erase(str(sid))
		e["id"] = bad
		d["staff"][str(bad)] = e
		assert_false(GameState.validate_dict(d), "id %d" % bad)


func test_validate_rejects_staff_skills_with_wrong_keys() -> void:
	var s := Fixtures.new_state(5)
	var sid := Fixtures.add_staff(s)
	var d := _rt(s)
	d["staff"][str(sid)]["skills"].erase("audio")
	assert_false(GameState.validate_dict(d), "missing")
	d = _rt(s)
	d["staff"][str(sid)]["skills"]["magic"] = 5
	assert_false(GameState.validate_dict(d), "extra")
	d = _rt(s)
	d["staff"][str(sid)]["skills"].erase("audio")
	d["staff"][str(sid)]["skills"]["magic"] = 5
	assert_false(GameState.validate_dict(d), "swapped")


func test_new_game_creates_owner_seated_with_equipment() -> void:
	var s := Fixtures.new_state(1)
	var owner: Staff = s.staff[s.owner_staff_id()]
	assert_true(owner.is_owner)
	assert_eq(owner.seat_index, 0)
	assert_eq(owner.salary, 0)
	for k: StringName in [&"design", &"tech", &"art", &"audio"]:
		assert_eq(owner.skills[k], 30)
	var eq: Equipment = s.equipment[3]
	assert_eq(eq.seat_index, 0)
	assert_eq(eq.def_id, &"equipment_micro_1980")
	assert_eq(s.companies[s.player_company_id].office_id, &"office_garage")


func test_new_game_creates_ai_companies_in_fixed_order() -> void:
	var s := Fixtures.new_state(1)
	var kinds: Array = s.sorted_ids(s.companies).map(func(id: int) -> String: return Company.Kind.keys()[s.companies[id].kind])
	assert_eq(kinds, ["PLAYER", "BANK", "LENDER", "VENDOR", "VENDOR", "AI_PUBLISHER", "AI_PUBLISHER", "AI_PUBLISHER"])
	assert_eq(s.next_id, 11)


func test_new_game_draws_no_rng() -> void:
	var s := Fixtures.new_state(1)
	var fresh := RandomNumberGenerator.new()
	fresh.seed = 1
	assert_eq(s.rng.state, fresh.state)


func test_m2_state_round_trip_preserves_hash() -> void:
	var s := Fixtures.new_state(5)
	Fixtures.add_engine(s)
	Fixtures.add_worker(s)
	var l := Loan.new()
	l.id = s.alloc_id()
	l.company_id = s.player_company_id
	l.lender_id = 4
	s.loans[l.id] = l
	var c := Candidate.new()
	c.id = s.alloc_id()
	c.skills = {&"art": 1, &"audio": 1, &"design": 1, &"tech": 1}
	s.candidates.append(c)
	var d := Fixtures.json_round_trip(s.to_dict())
	assert_true(GameState.validate_dict(d))
	assert_eq(StateHash.of(GameState.from_dict(d)), StateHash.of(s))
