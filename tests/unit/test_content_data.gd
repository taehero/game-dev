extends GutTest
## Real data. Content tasks append pinned-value tests.


func test_real_content_loads_without_errors() -> void:
	var db := ContentDB.load_dir()
	assert_eq(db.errors, [] as Array[String])
	assert_eq(db.validate(), [] as Array[String])


func test_m2a_platforms_sizes_offices() -> void:
	var db := ContentDB.load_dir()
	assert_eq(db.platforms.size(), 5)
	assert_eq(db.platforms[&"platform_nova8"].dev_kit_cost, 0)
	assert_gte(db.platforms[&"platform_nova8"].install_curve[0], 40000)
	assert_eq(db.sizes[&"size_small"].base_weeks, 18)
	assert_eq(db.offices[&"office_garage"].seats, 2)
	assert_eq(db.offices[&"office_small"].seats, 5)
	assert_eq(db.levels.size(), 4)
	assert_eq(db.licensed_engines[&"lic_engine_homebrew"].fee, 0)
	for id: StringName in GameState.sorted_names(db.platforms):
		assert_ne(tr(db.platforms[id].name_key), String(db.platforms[id].name_key))
