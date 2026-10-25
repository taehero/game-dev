extends GutTest


func test_content_paths_maps_remap_names() -> void:
	var dir := "user://content_test_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir + "/b")
	for f: String in ["/b/z.tres.remap", "/a.tres", "/note.txt"]:
		FileAccess.open(dir + f, FileAccess.WRITE).close()
	assert_eq(ContentDB.content_paths(dir), [dir + "/a.tres", dir + "/b/z.tres"] as Array[String])


func test_duplicate_id_is_an_error_and_first_wins() -> void:
	var db := ContentDB.new()
	var a := GenreDef.new(); a.id = &"genre_x"; a.ideal_sliders = [10000,0,0,10000,0,0,10000,0,0]
	var b := TopicDef.new(); b.id = &"genre_x"
	assert_true(db.add(a))
	assert_false(db.add(b))
	assert_push_error("duplicate content id")
	assert_eq(db.errors.size(), 1)
	assert_true(db.genres.has(&"genre_x"))
	assert_false(db.topics.has(&"genre_x"))


func test_fixture_content_is_valid() -> void:
	assert_eq(Fixtures.content().validate(), [] as Array[String])
	assert_eq(Fixtures.content().errors, [] as Array[String])


func test_validate_catches_bad_sliders_and_dangling_unlock() -> void:
	var db := ContentDB.new()
	var g := GenreDef.new(); g.id = &"genre_bad"; g.ideal_sliders = [5000, 5000, 1, 10000, 0, 0, 10000, 0, 0]
	var r := ResearchDef.new(); r.id = &"research_bad"; r.unlocks = [&"topic_missing"]
	db.add(g); db.add(r)
	assert_eq(db.validate().size(), 2)


func test_unlocked_rules() -> void:
	var db := Fixtures.content()
	assert_true(db.is_unlocked([], &"genre_fx_action"))
	assert_false(db.is_unlocked([], &"genre_fx_adventure"))
	assert_true(db.is_unlocked([&"research_fx_adventure"], &"genre_fx_adventure"))


func test_new_state_installs_fixture_content() -> void:
	Fixtures.new_state(1)
	assert_same(ContentDB.active(), Fixtures.content())


func test_fixture_pinned_values() -> void:
	var db := Fixtures.content()
	assert_eq(db.offices[&"office_garage"].desk_positions, [Vector2i(2, 2), Vector2i(5, 2)] as Array[Vector2i])
	assert_eq(db.equipment[&"equipment_fx_fast"].tier, 2)
	assert_eq(db.level_def(2).id, &"level_senior")
	assert_null(db.level_def(9))
	assert_eq(db.locking_research(&"topic_fx_ghost"), [&"research_fx_adventure"] as Array[StringName])
	assert_eq(db.review_templates.size(), 22)


func test_missing_refs_lists_unknown_equipment_def() -> void:
	var s: GameState = Fixtures.new_state(1)
	assert_eq(Fixtures.content().missing_refs(s), [] as Array[String])
	var eq_id: int = Fixtures.add_equipment(s, {"def_id": &"equipment_gone"})
	assert_eq(s.equipment[eq_id].def_id, &"equipment_gone")
	assert_eq(Fixtures.content().missing_refs(s).size(), 1)


func _one_missing(s: GameState, needle: String) -> void:
	var m: Array[String] = Fixtures.content().missing_refs(s)
	assert_eq(m.size(), 1, "expected one message for %s, got %s" % [needle, m])
	if m.size() == 1:
		assert_string_contains(m[0], needle)


func _fresh() -> GameState:
	return Fixtures.new_state(1)


func _pc(s: GameState) -> Company:
	return s.companies[s.player_company_id]


func test_missing_refs_office() -> void:
	var s: GameState = _fresh()
	_pc(s).office_id = &"office_gone"
	_one_missing(s, "office_gone")


func test_missing_refs_research() -> void:
	var s: GameState = _fresh()
	_pc(s).unlocked.append(&"research_gone")
	_one_missing(s, "research_gone")


func test_missing_refs_dev_kit() -> void:
	var s: GameState = _fresh()
	_pc(s).dev_kits.append(&"platform_gone")
	_one_missing(s, "platform_gone")


func test_missing_refs_award() -> void:
	var s: GameState = _fresh()
	_pc(s).awards.append(&"award_gone")
	_one_missing(s, "award_gone")


func test_missing_refs_project_size() -> void:
	var s: GameState = _fresh()
	var id: int = Fixtures.add_project(s)
	s.projects[id].size_id = &"size_gone"
	_one_missing(s, "size_gone")


func test_missing_refs_project_config() -> void:
	for key: StringName in [&"platform", &"genre", &"topic", &"engine"]:
		var s: GameState = _fresh()
		var id: int = Fixtures.add_project(s)
		s.projects[id].config[key] = &"thing_gone"
		_one_missing(s, "thing_gone")


func test_missing_refs_project_feature_and_outlet() -> void:
	var s: GameState = _fresh()
	var id: int = Fixtures.add_project(s)
	s.projects[id].features.append(&"feature_gone")
	_one_missing(s, "feature_gone")
	var s2: GameState = _fresh()
	var id2: int = Fixtures.add_project(s2)
	var rr := ReviewResult.new()
	rr.outlet_id = &"outlet_gone"
	s2.projects[id2].review_results.append(rr)
	_one_missing(s2, "outlet_gone")


func test_missing_refs_engine_feature() -> void:
	var s: GameState = _fresh()
	var id: int = Fixtures.add_engine(s)
	s.engines[id].features.append(&"feature_gone")
	_one_missing(s, "feature_gone")


func test_missing_refs_seat_beyond_office() -> void:
	var s: GameState = _fresh()
	var id: int = Fixtures.add_staff(s, {"seat_index": 99})
	assert_eq(s.staff[id].seat_index, 99)
	_one_missing(s, "seat 99")
	var s2: GameState = _fresh()
	Fixtures.add_equipment(s2, {"seat_index": 99})
	_one_missing(s2, "seat 99")


func test_missing_refs_contract_fields() -> void:
	var s: GameState = _fresh()
	var c := Contract.new()
	c.id = s.alloc_id()
	c.locked_genre = &"genre_gone"
	s.contracts[c.id] = c
	_one_missing(s, "genre_gone")
	c.locked_genre = &""
	c.locked_platform = &"platform_gone"
	_one_missing(s, "platform_gone")
	c.locked_platform = &""
	c.kind = Contract.Kind.ENGINE_LICENSE
	c.deliverable = &"engine_gone"
	_one_missing(s, "engine_gone")
	c.kind = Contract.Kind.PUBLISHING
	assert_eq(Fixtures.content().missing_refs(s).size(), 0, "deliverable ignored unless ENGINE_LICENSE")


func test_missing_refs_owner_perk() -> void:
	var s: GameState = _fresh()
	s.owner.perks[&"perk_gone"] = 1
	_one_missing(s, "perk_gone")
