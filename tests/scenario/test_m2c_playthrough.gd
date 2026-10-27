extends GutTest
const WEEKS := 80
var real: ContentDB
var tuning: TuningDef


func before_all() -> void:
	real = ContentDB.load_dir()
	tuning = TuningDef.load_default()


func after_all() -> void:
	ContentDB.use(Fixtures.content())


func _new_state(p_seed: int) -> GameState:
	return GameState.new_game(p_seed, "Test Studio", tuning)


func _run(p_seed: int, weeks: int = WEEKS, script: Dictionary = ScenarioM2C.SCRIPT_M2C) -> GameState:
	var s := _new_state(p_seed)
	Scenario.advance(s, script, weeks, real, tuning)
	return s


func _games(s: GameState) -> Array[Project]:
	var out: Array[Project] = []
	for id: int in s.sorted_ids(s.projects):
		if s.projects[id].kind == Project.Kind.GAME and s.projects[id].parent_id == -1:
			out.append(s.projects[id])
	return out


func test_playthrough_reaches_every_m2c_milestone() -> void:
	var s := _run(2026)
	var games := _games(s)
	assert_eq(games.size(), 2)
	var g2: Project = games[1]
	var dlc: Project = null
	for id: int in s.sorted_ids(s.projects):
		if s.projects[id].parent_id == g2.id:
			dlc = s.projects[id]
	assert_not_null(dlc)
	assert_eq(g2.dlc_count, 1)
	assert_true(dlc.phase >= Project.Phase.RELEASED and dlc.review_results.size() == 4)
	assert_true(g2.mod_tools)
	assert_eq(g2.live_task, Project.LiveTask.NONE)
	assert_gt(g2.user_score, AwardsSystem.entry_score_x10(g2))
	assert_eq(g2.award_entry, &"")
	assert_eq([g2.promo_discount_bp, g2.promo_until_week], [3000, 73])
	assert_gt(s.companies[s.player_company_id].promo_fatigue, 0)
	for sid: int in s.sorted_ids(s.staff):
		assert_eq(s.staff[sid].assigned_project_id, -1)
	assert_true(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))
	assert_eq(real.missing_refs(s), [] as Array[String])


func test_marketing_raises_launch_sales() -> void:
	var without: Dictionary = ScenarioM2C.SCRIPT_M2C.duplicate(true)
	without.erase(15)
	var a := _games(_run(2026, 30))[0]
	var b := _games(_run(2026, 30, without))[0]
	assert_gt(a.weekly_units[0], b.weekly_units[0])


func test_same_seed_same_hash() -> void:
	assert_eq(StateHash.of(_run(7)), StateHash.of(_run(7)))


func test_different_seed_different_hash() -> void:
	assert_ne(StateHash.of(_run(7)), StateHash.of(_run(8)))


## 15 marketing, 49 award entry pending, 50 ceremony + mid-patch, 56 mid-DLC, 69 mid-promotion, 73 after the fatigue promotion.
func test_save_load_continue_matches_uninterrupted() -> void:
	var full := StateHash.of(_run(7))
	for save_week: int in [15, 49, 50, 56, 69, 73]:
		var s := _new_state(7)
		Scenario.advance(s, ScenarioM2C.SCRIPT_M2C, save_week, real, tuning)
		var loaded := SaveService.deserialize(SaveService.serialize(s))
		assert_true(loaded.ok, "load at %d" % save_week)
		Scenario.advance(loaded.state, ScenarioM2C.SCRIPT_M2C, WEEKS - save_week, real, tuning)
		assert_eq(StateHash.of(loaded.state), full, "save at week %d" % save_week)


func test_values_stay_in_range() -> void:
	var s := _run(7)
	for id: int in s.sorted_ids(s.projects):
		var p: Project = s.projects[id]
		assert_between(p.hype, 0, 100)
		assert_between(p.sentiment, -100, 100)
		assert_gte(p.sales_base_units, 0)
		if p.kind == Project.Kind.GAME and p.phase >= Project.Phase.RELEASED:
			assert_between(p.user_score, 10, 100)
