extends GutTest


func test_project_m2c_fields_round_trip() -> void:
	var p := Project.new()
	p.id = 5
	p.company_id = 1
	p.parent_id = 3
	p.live_task = Project.LiveTask.MOD_TOOLS
	p.live_task_left = 6
	p.award_entry = &"award_fx"
	p.sales_base_units = 777
	p.sentiment = -40
	var back := Project.from_dict(Fixtures.json_round_trip(p.to_dict()))
	assert_eq([back.parent_id, back.live_task, back.live_task_left, back.award_entry, back.sales_base_units, back.sentiment],
		[3, Project.LiveTask.MOD_TOOLS, 6, &"award_fx", 777, -40])


func test_company_promo_fatigue_round_trip() -> void:
	var c := Company.new()
	c.promo_fatigue = 12
	assert_eq(Company.from_dict(Fixtures.json_round_trip(c.to_dict())).promo_fatigue, 12)


func test_remove_forum_post_keeps_state_valid() -> void:
	var s := Fixtures.new_state(3)
	var pid := Fixtures.add_project(s)
	var post := ForumPost.new()
	post.id = s.alloc_id()
	post.project_id = pid
	post.topic_key = &"forum.post.bugs"
	s.forum_posts.append(post)
	var dec := Decision.new()
	dec.id = s.alloc_id()
	dec.related_ids.append(post.id)
	s.pending_decisions.append(dec)
	assert_true(Removal.remove_forum_post(s, post.id))
	assert_true(s.forum_posts.is_empty())
	assert_true(s.pending_decisions.is_empty())
	assert_true(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))
	assert_false(Removal.remove_forum_post(s, post.id))


func test_missing_refs_flags_unknown_award_entry() -> void:
	var s := Fixtures.new_state(3)
	Fixtures.add_project(s, {"award_entry": &"award_gone"})
	var msgs := Fixtures.content().missing_refs(s)
	assert_eq(msgs.size(), 1)
	assert_string_contains(msgs[0], "award_gone")


func test_fixture_m2c_content() -> void:
	var db := Fixtures.content()
	assert_eq(db.channels.size(), 5)
	assert_true(db.awards.has(&"award_fx"))
	assert_true(db.sizes[&"size_dlc"].dlc)
