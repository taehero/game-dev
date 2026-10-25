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


func test_m2a_genres_topics_research() -> void:
	var db := ContentDB.load_dir()
	assert_eq(db.validate(), [] as Array[String])
	assert_eq(db.genres.size(), 6)
	assert_eq(db.topics.size(), 20)
	assert_true(db.topics.has(&"topic_thai_ghost"))
	assert_eq(db.topics[&"topic_space"].genre_fit_bp[&"genre_action"], 15000)
	assert_gte(db.topics[&"topic_sports"].genre_fit_bp[&"genre_action"], 12000)
	assert_true(db.is_unlocked([], &"topic_space") and db.is_unlocked([], &"topic_sports"))
	assert_false(db.is_unlocked([], &"topic_thai_ghost"))
	assert_eq(db.research[&"research_scrolling"].cost_rp, 200)
	assert_eq(db.licensed_engines.size(), 3)
	assert_true(db.is_unlocked([], &"genre_action"))
	assert_false(db.is_unlocked([], &"genre_rpg"))
	assert_false(db.is_unlocked([], &"size_medium"))
	var open_topics := GameState.sorted_names(db.topics).filter(func(id: StringName) -> bool: return db.is_unlocked([], id))
	assert_eq(open_topics.size(), 14)
	for id: StringName in GameState.sorted_names(db.genres):
		assert_ne(tr(db.genres[id].name_key), String(db.genres[id].name_key))


func test_m2a_outlets_and_templates() -> void:
	var db := ContentDB.load_dir()
	assert_eq(db.outlets.size(), 4)
	for dim: StringName in ReviewOutletDef.DIMENSIONS:
		var strong := 0
		var weak := 0
		for id: StringName in GameState.sorted_names(db.review_templates):
			var t: ReviewTemplateDef = db.review_templates[id]
			if t.dimension == dim:
				if t.is_strength:
					strong += 1
				else:
					weak += 1
		assert_gte(strong, 2, String(dim))
		assert_gte(weak, 2, String(dim))
	for id: StringName in GameState.sorted_names(db.review_templates):
		var key: StringName = db.review_templates[id].text_key
		assert_ne(tr(key), String(key), String(key))
