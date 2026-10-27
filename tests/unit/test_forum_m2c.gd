extends GutTest


func _tuning(chance: int = 10000) -> TuningDef:
	var t: TuningDef = Fixtures.tuning()
	t.forum_post_base_chance_bp = chance
	t.forum_post_max_chance_bp = maxi(chance, t.forum_post_max_chance_bp)
	return t


func _review() -> Array[ReviewResult]:
	var rs: Array[ReviewResult] = []
	rs.append(ReviewResult.new())
	return rs


func _live(s: GameState, o: Dictionary = {}) -> Project:
	var d: Dictionary = {"phase": Project.Phase.LIVE}
	d.merge(o, true)
	return s.projects[Fixtures.add_project(s, d)]


func _tick(s: GameState, t: TuningDef) -> TickContext:
	var ctx := TickContext.new(s, t)
	LiveOpsSystem.tick(ctx)
	return ctx


func _post(s: GameState, pid: int, replied: bool = false) -> ForumPost:
	var ctx := TickContext.new(s, Fixtures.tuning())
	var id: int = LiveOpsSystem.add_forum_post(ctx, pid, &"forum.post.bugs", -5, replied)
	return s.forum_posts[s.forum_posts.size() - 1] if id != -1 else null


func test_forum_chance_formula() -> void:
	var s := Fixtures.new_state(1)
	assert_eq(LiveOpsSystem.forum_chance_bp(_live(s, {"bugs": 10}), Fixtures.tuning()), 1000)
	assert_eq(LiveOpsSystem.forum_chance_bp(_live(s, {"bugs": 1000}), Fixtures.tuning()), 3000)


func test_bug_post_when_only_bugs() -> void:
	var s := Fixtures.new_state(1)
	var p := _live(s, {"bugs": 5})
	var ctx := _tick(s, _tuning())
	assert_eq(s.forum_posts.size(), 1)
	assert_eq(s.forum_posts[0].topic_key, &"forum.post.bugs")
	assert_false(s.forum_posts[0].replied)
	assert_eq(p.sentiment, -5)
	var n: int = 0
	for e: Dictionary in ctx.events:
		if e["name"] == &"forum_post_created":
			n += 1
	assert_eq(n, 1)


func test_weakness_post_when_only_reviews() -> void:
	var s := Fixtures.new_state(1)
	_live(s, {"bugs": 0, "review_results": _review()})
	_tick(s, _tuning())
	assert_eq(s.forum_posts.size(), 1)
	assert_eq(s.forum_posts[0].topic_key, &"forum.post.weakness")


func test_no_post_without_source() -> void:
	var s := Fixtures.new_state(1)
	_live(s, {"bugs": 0})
	_tick(s, _tuning())
	assert_eq(s.forum_posts.size(), 0)


func test_no_post_for_released_or_retired() -> void:
	var s := Fixtures.new_state(1)
	_live(s, {"bugs": 5, "phase": Project.Phase.RELEASED})
	_live(s, {"bugs": 5, "phase": Project.Phase.RETIRED})
	var before: int = s.rng.state
	_tick(s, _tuning())
	assert_eq(s.forum_posts.size(), 0)
	assert_eq(s.rng.state, before)


func test_forum_cap_drops_oldest() -> void:
	var s := Fixtures.new_state(1)
	_live(s, {"bugs": 5})
	var t: TuningDef = _tuning()
	t.forum_posts_cap = 2
	_tick(s, t)
	var ids: Array[int] = [s.forum_posts[0].id]
	_tick(s, t)
	ids.append(s.forum_posts[s.forum_posts.size() - 1].id)
	_tick(s, t)
	ids.append(s.forum_posts[s.forum_posts.size() - 1].id)
	assert_eq(s.forum_posts.size(), 2)
	assert_eq(s.forum_posts[0].id, ids[1])
	assert_eq(s.forum_posts[1].id, ids[2])
	assert_true(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))


func test_cap_zero_emits_no_forum_post_event() -> void:
	var s := Fixtures.new_state(1)
	_live(s, {"bugs": 5})
	var t: TuningDef = _tuning()
	t.forum_posts_cap = 0
	var ctx := _tick(s, t)
	assert_eq(s.forum_posts.size(), 0)
	for e: Dictionary in ctx.events:
		assert_ne(e["name"], &"forum_post_created")


func test_same_seed_same_posts() -> void:
	var out: Array = []
	for _i in 2:
		var s := Fixtures.new_state(3)
		_live(s, {"bugs": 5, "review_results": _review()})
		var t: TuningDef = _tuning(5000)
		for _k in 10:
			_tick(s, t)
		var posts: Array = []
		for f: ForumPost in s.forum_posts:
			posts.append(f.to_dict())
		out.append(posts)
	assert_eq(out[0], out[1])


func _mod_project(s: GameState) -> Project:
	return _live(s, {"mod_tools": true, "sales_base_units": 1000, "weekly_units": [1000]})


func test_viral_on_month_start() -> void:
	var s := Fixtures.new_state(1)
	var p := _mod_project(s)
	var t: TuningDef = _tuning(0)
	t.mod_viral_chance_bp = 10000
	var company: Company = s.companies[p.company_id]
	var fans: int = company.fan_count
	var rev: int = p.revenue
	_tick(s, t)
	assert_eq(company.fan_count, fans + 2000)
	assert_eq(p.weekly_units, [2000] as Array[int])
	assert_eq(p.units_sold, 1000)
	assert_eq(p.revenue - rev, 12000)
	assert_eq(s.forum_posts.size(), 1)
	assert_eq(s.forum_posts[0].topic_key, &"forum.post.mod_viral")
	assert_true(s.forum_posts[0].replied)
	assert_eq(p.sentiment, 10)


func test_no_viral_off_month_start() -> void:
	var s := Fixtures.new_state(1)
	s.week = 1
	var p := _mod_project(s)
	var t: TuningDef = _tuning(0)
	t.mod_viral_chance_bp = 10000
	var company: Company = s.companies[p.company_id]
	var fans: int = company.fan_count
	_tick(s, t)
	assert_eq(company.fan_count, fans)
	assert_eq(s.forum_posts.size(), 0)


func test_reply_apologise() -> void:
	var s := Fixtures.new_state(1)
	var p := _live(s)
	var post := _post(s, p.id)
	var cmd := ReplyForumCommand.new(post.id, &"apologise")
	assert_true(cmd.validate(s, Fixtures.tuning()).ok)
	cmd.apply(TickContext.new(s, Fixtures.tuning()))
	assert_true(post.replied)
	assert_eq(p.sentiment, 3 - 5)


func test_reply_promise_needs_patch() -> void:
	var s := Fixtures.new_state(1)
	var p := _live(s)
	var post := _post(s, p.id)
	var cmd := ReplyForumCommand.new(post.id, &"promise_patch")
	assert_eq(cmd.validate(s, Fixtures.tuning()).reason_key, &"error.no_patch_running")
	p.live_task = Project.LiveTask.PATCH
	assert_true(cmd.validate(s, Fixtures.tuning()).ok)
	cmd.apply(TickContext.new(s, Fixtures.tuning()))
	assert_eq(p.sentiment, 8 - 5)


func test_reply_ignore() -> void:
	var s := Fixtures.new_state(1)
	var p := _live(s)
	var post := _post(s, p.id)
	ReplyForumCommand.new(post.id, &"ignore").apply(TickContext.new(s, Fixtures.tuning()))
	assert_true(post.replied)
	assert_eq(p.sentiment, -5)


func test_reply_twice_rejected() -> void:
	var s := Fixtures.new_state(1)
	var post := _post(s, _live(s).id, true)
	assert_eq(ReplyForumCommand.new(post.id, &"ignore").validate(s, Fixtures.tuning()).reason_key, &"error.post_replied")


func test_reply_bad_inputs() -> void:
	var s := Fixtures.new_state(1)
	var post := _post(s, _live(s).id)
	assert_eq(ReplyForumCommand.new(post.id, &"shrug").validate(s, Fixtures.tuning()).reason_key, &"error.invalid_reply")
	assert_eq(ReplyForumCommand.new(9999, &"ignore").validate(s, Fixtures.tuning()).reason_key, &"error.post_not_found")
