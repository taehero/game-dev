extends GutTest
const WEEKS := 80
var real: ContentDB
var tuning: TuningDef


func before_all() -> void:
	real = ContentDB.load_dir()
	tuning = TuningDef.load_default()


func after_all() -> void:
	ContentDB.use(Fixtures.content())


func _run(p_seed: int, weeks: int = WEEKS) -> GameState:
	var s := _new_state(p_seed)
	Scenario.advance(s, Scenario.SCRIPT_M2A, weeks, real, tuning)
	return s


## Runs with the shipped data/tuning.tres, not the Fixtures defaults.
func _new_state(p_seed: int) -> GameState:
	return GameState.new_game(p_seed, "Test Studio", tuning)


func _games(s: GameState) -> Array[Project]:
	var out: Array[Project] = []
	for id: int in s.sorted_ids(s.projects):
		if s.projects[id].kind == Project.Kind.GAME:
			out.append(s.projects[id])
	return out


func test_playthrough_reaches_every_m2a_milestone() -> void:
	var s := _run(2026)
	assert_eq(s.staff.size(), 2)
	assert_has(s.companies[1].unlocked, &"research_scrolling")
	assert_has(s.companies[1].dev_kits, &"platform_arcadia")
	assert_eq(s.engines.size(), 1)
	var games := _games(s)
	assert_eq(games.size(), 2)
	for g: Project in games:
		assert_true(g.phase >= Project.Phase.RELEASED)
		assert_eq(g.review_results.size(), 4)
		for r: ReviewResult in g.review_results:
			assert_ne(tr(r.strength_key), String(r.strength_key))
			assert_ne(tr(r.weakness_key), String(r.weakness_key))
	assert_gte(games[0].weekly_units.size(), 20)
	assert_true(games[0].units_sold > 0 and games[1].units_sold > 0)
	assert_eq(games[1].engine_id, s.engines.keys()[0])
	assert_true(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))
	assert_eq(real.missing_refs(s), [] as Array[String])


func test_review_reasons_match_dimensions() -> void:
	var s := _run(2026)
	for g: Project in _games(s):
		var dims := ReviewSystem.dimension_scores(s, real, tuning, g.id)
		for r: ReviewResult in g.review_results:
			var o: ReviewOutletDef = real.outlets[r.outlet_id]
			var expect := ReviewSystem.outlet_review(dims, o, real, RandomNumberGenerator.new(), tuning)
			assert_eq(r.strength_key, expect.strength_key)
			assert_eq(r.weakness_key, expect.weakness_key)


func test_same_seed_same_hash() -> void:
	assert_eq(StateHash.of(_run(7)), StateHash.of(_run(7)))


func test_different_seed_different_hash() -> void:
	assert_ne(StateHash.of(_run(7)), StateHash.of(_run(8)))


## 0, 22 and 28 are command weeks, 13 and 26 are quarter starts, 20 is a release week, 50 is during sales.
## Commands at 20, 22, 28 and 48 run after the earlier save points, so RNG is still drawn after a load.
func test_save_load_continue_matches_uninterrupted() -> void:
	var full := StateHash.of(_run(7))
	for save_week: int in [0, 13, 20, 22, 26, 28, 50]:
		var s := _new_state(7)
		Scenario.advance(s, Scenario.SCRIPT_M2A, save_week, real, tuning)
		var loaded := SaveService.deserialize(SaveService.serialize(s))
		assert_true(loaded.ok, "load at %d" % save_week)
		Scenario.advance(loaded.state, Scenario.SCRIPT_M2A, WEEKS - save_week, real, tuning)
		assert_eq(StateHash.of(loaded.state), full, "save at week %d" % save_week)


func test_values_stay_in_range() -> void:
	var s := _run(7)
	for id: int in s.sorted_ids(s.staff):
		assert_between(s.staff[id].morale, 0, 100)
	for g: Project in _games(s):
		assert_between(g.user_score, 10, 100)
		assert_true(g.bugs >= 0)
