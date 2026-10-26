extends GutTest
const WEEKS := 90
var _answered: int = 0


func before_all() -> void:
	Fixtures.use_real_content()


func after_all() -> void:
	ContentDB.use(Fixtures.content())


func _session(p_seed: int) -> GameSession:
	return GameSession.new(GameState.new_game(p_seed, "Test Studio", UiLoopDriver.tuning()), UiLoopDriver.tuning())


func _run(p_seed: int) -> GameSession:
	var s := _session(p_seed)
	_answered = UiLoopDriver.advance(s, WEEKS)
	return s


func _games(s: GameState) -> Array[Project]:
	var out: Array[Project] = []
	for id: int in s.sorted_ids(s.projects):
		if s.projects[id].kind == Project.Kind.GAME:
			out.append(s.projects[id])
	return out


func test_playthrough_reaches_every_m2d_milestone() -> void:
	var session := _run(7)
	var s: GameState = session.state
	var games := _games(s)
	assert_eq(games.size(), 2)
	for g: Project in games:
		assert_true(g.phase >= Project.Phase.RELEASED)
		assert_eq(g.review_results.size(), 4)
		for r: ReviewResult in g.review_results:
			assert_ne(tr(r.strength_key), String(r.strength_key))
			assert_ne(tr(r.weakness_key), String(r.weakness_key))
		assert_eq(g.event_ids.size(), 2)
		assert_true(g.bug_hunt_done)
		assert_true(g.revenue > 0)
	var feats: Array[StringName] = [&"feature_scrolling"]
	assert_eq(games[1].engine_id, s.sorted_ids(s.engines)[0])
	assert_eq(games[1].features, feats)
	assert_eq(games[1].config[&"platform"], &"platform_arcadia")
	var company: Company = s.companies[s.player_company_id]
	assert_has(company.dev_kits, &"platform_arcadia")
	assert_has(company.unlocked, &"research_scrolling")
	var rows := StateQueries.staff_rows(s)
	assert_eq(rows.size(), 2)
	var found_ada: bool = false
	for row: Dictionary in rows:
		if row["name"] == "Ada":
			found_ada = true
			assert_false(row["has_computer"])
	assert_true(found_ada, "Ada is on staff")
	assert_gte(_answered, 4)
	assert_gte(games[0].weekly_units.size(), 20)
	assert_true(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))
	assert_eq(ContentDB.active().missing_refs(s), [] as Array[String])


func test_same_seed_same_hash() -> void:
	assert_eq(StateHash.of(_run(7).state), StateHash.of(_run(7).state))


func test_different_seed_different_hash() -> void:
	assert_ne(StateHash.of(_run(7).state), StateHash.of(_run(8).state))


## First week boundary (after step_once) where an event is pending, found with a probe run.
func _first_pending_week() -> int:
	var s := _session(7)
	for w: int in WEEKS:
		UiLoopDriver.week_actions(s)
		s.step_once()
		if not StateQueries.pending_event_ids(s.state, ContentDB.active()).is_empty():
			return w + 1
	return -1


## First week boundary where the active project is a GAME in POLISH.
func _first_polish_week() -> int:
	var s := _session(7)
	for w: int in WEEKS:
		UiLoopDriver.week_actions(s)
		s.step_once()
		var pid: int = StateQueries.active_project_id(s.state)
		if pid != -1 and s.state.projects[pid].kind == Project.Kind.GAME and s.state.projects[pid].phase == Project.Phase.POLISH:
			return w + 1
	return -1


func test_save_load_continue_matches_uninterrupted() -> void:
	var full := StateHash.of(_run(7).state)
	var first_pending: int = _first_pending_week()
	assert_gt(first_pending, 0, "an event becomes pending")
	var first_polish: int = _first_polish_week()
	assert_gt(first_polish, 0, "a game reaches polish")
	for save_week: int in [first_pending, first_polish, 10, 25, 40, 60]:
		var s := _session(7)
		UiLoopDriver.advance(s, save_week)
		if save_week == first_pending:
			assert_false(StateQueries.pending_event_ids(s.state, ContentDB.active()).is_empty(), "pending event at save")
		if save_week == first_polish:
			var pid: int = StateQueries.active_project_id(s.state)
			assert_eq(s.state.projects[pid].phase, Project.Phase.POLISH, "polish at save")
		var loaded := SaveService.deserialize(SaveService.serialize(s.state))
		assert_true(loaded.ok, "load at %d" % save_week)
		var resumed := GameSession.new(loaded.state, UiLoopDriver.tuning())
		UiLoopDriver.advance(resumed, WEEKS - save_week)
		assert_eq(StateHash.of(resumed.state), full, "save at week %d" % save_week)


func test_values_stay_in_range() -> void:
	var s: GameState = _run(7).state
	for id: int in s.sorted_ids(s.staff):
		assert_between(s.staff[id].morale, 0, 100)
	for g: Project in _games(s):
		assert_between(g.hype, 0, 100)
		assert_between(g.user_score, 10, 100)
		assert_true(g.bugs >= 0)
