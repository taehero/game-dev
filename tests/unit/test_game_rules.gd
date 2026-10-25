extends GutTest

var db: ContentDB


func before_each() -> void:
	db = Fixtures.content()


func test_platform_status_timeline() -> void:
	var p: PlatformDef = db.platforms[&"platform_fx_console"]  # launch 20, end 60, rumor 8
	assert_eq(GameRules.platform_status(p, 11), GameRules.PlatformStatus.UNANNOUNCED)
	assert_eq(GameRules.platform_status(p, 12), GameRules.PlatformStatus.RUMORED)
	assert_eq(GameRules.platform_status(p, 20), GameRules.PlatformStatus.ON_SALE)
	assert_eq(GameRules.platform_status(p, 60), GameRules.PlatformStatus.RETIRED)


func test_free_dev_kit_counts_as_owned() -> void:
	var s := Fixtures.new_state(1)
	assert_true(GameRules.has_dev_kit(s, db, 1, &"platform_fx_micro"))
	assert_false(GameRules.has_dev_kit(s, db, 1, &"platform_fx_console"))
	s.companies[1].dev_kits.append(&"platform_fx_console")
	assert_true(GameRules.has_dev_kit(s, db, 1, &"platform_fx_console"))


func test_free_workers_need_seat_and_equipment() -> void:
	var s := Fixtures.new_state(1)
	var unseated := Fixtures.add_staff(s)
	var seated_no_pc := Fixtures.add_staff(s, {"seat_index": 1})
	assert_eq(GameRules.free_workers(s, 1), [s.owner_staff_id()] as Array[int])
	Fixtures.add_equipment(s, {"seat_index": 1})
	assert_eq(GameRules.free_workers(s, 1), [s.owner_staff_id(), seated_no_pc] as Array[int])
	assert_false(GameRules.free_workers(s, 1).has(unseated))


func test_seats_and_equipment_at_seat() -> void:
	var s := Fixtures.new_state(1)
	assert_eq(GameRules.office_seats(s, db, 1), 2)
	assert_eq(GameRules.free_seat(s, db, 1), 1)
	assert_ne(GameRules.equipment_at_seat(s, 1, 0), -1)
	assert_eq(GameRules.equipment_at_seat(s, 1, 1), -1)
	Fixtures.add_staff(s, {"seat_index": 1})
	assert_eq(GameRules.free_seat(s, db, 1), -1)


func test_working_staff_excludes_unequipped_and_other_projects() -> void:
	var s := Fixtures.new_state(1)
	var pid := Fixtures.add_project(s)
	s.staff[s.owner_staff_id()].assigned_project_id = pid
	var other := Fixtures.add_staff(s, {"seat_index": 1, "assigned_project_id": pid})
	assert_eq(GameRules.working_staff(s, pid), [s.owner_staff_id()] as Array[int])
	Fixtures.add_equipment(s, {"seat_index": 1})
	assert_eq(GameRules.working_staff(s, pid), [s.owner_staff_id(), other] as Array[int])


func test_stage_weeks_and_min_staff() -> void:
	var s := Fixtures.new_state(1)
	var t := Fixtures.tuning()
	var g: Project = s.projects[Fixtures.add_project(s)]
	assert_eq(GameRules.stage_weeks(g, db, t), 6)
	assert_eq(GameRules.min_staff(g, db, t), 1)
	assert_eq(GameRules.stage_count(g), 3)
	var e: Project = s.projects[Fixtures.add_project(s, {"kind": Project.Kind.ENGINE, "size_id": &"",
		"features": [&"feature_fx_save", &"feature_fx_scroll"] as Array[StringName]})]
	assert_eq(GameRules.stage_count(e), 1)
	assert_eq(GameRules.stage_weeks(e, db, t), 6)
	assert_eq(GameRules.min_staff(e, db, t), t.engine_min_staff)


func test_engine_focus_is_all_code() -> void:
	assert_eq(GameRules.ENGINE_FOCUS.size(), 9)
	assert_eq(GameRules.SLIDER_TYPES.size(), 9)


func test_engine_features_and_tech_cap() -> void:
	var s := Fixtures.new_state(1)
	var eid := Fixtures.add_engine(s, {"tech_cap": 42, "features": [&"feature_fx_save"] as Array[StringName]})
	assert_eq(GameRules.engine_features(s, db, eid, &""), [&"feature_fx_save"] as Array[StringName])
	var lic: LicensedEngineDef = db.licensed_engines[&"lic_engine_homebrew"]
	assert_eq(GameRules.engine_features(s, db, -1, &"lic_engine_homebrew"), lic.features)
	var p: Project = s.projects[Fixtures.add_project(s, {"engine_id": eid})]
	assert_eq(GameRules.engine_tech_cap(s, db, p), 42)
	var q: Project = s.projects[Fixtures.add_project(s, {"engine_id": -1,
		"config": {&"engine": &"lic_engine_homebrew"} as Dictionary[StringName, StringName]})]
	assert_eq(GameRules.engine_tech_cap(s, db, q), lic.tech_cap)


func test_licensed_engine_needs_contract_unless_free() -> void:
	var s := Fixtures.new_state(1)
	var t := Fixtures.tuning()
	assert_true(GameRules.licensed_engine_available(s, db, 1, &"lic_engine_homebrew", 0, t))
	assert_false(GameRules.licensed_engine_available(s, db, 1, &"lic_engine_fx_pro", 0, t))
	var c := Contract.new()
	c.id = s.alloc_id()
	c.kind = Contract.Kind.ENGINE_LICENSE
	c.party_a = 1
	c.party_b = 6
	c.deliverable = &"lic_engine_fx_pro"
	s.contracts[c.id] = c
	assert_true(GameRules.licensed_engine_available(s, db, 1, &"lic_engine_fx_pro", 0, t))
	assert_false(GameRules.licensed_engine_available(s, db, 1, &"lic_missing", 0, t))
