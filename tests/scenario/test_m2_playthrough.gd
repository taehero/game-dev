extends GutTest
## Spec §13 combined M2 playthrough: M2b (loan, hire, equipment, contract work) and M2c (marketing, release,
## promotion, patch, forum reply, award entry) through commands, driven by ScenarioM2b's loop.
const WEEKS := 80
var plan: Dictionary
var real: ContentDB
var tuning: TuningDef


func before_all() -> void:
	real = ContentDB.load_dir()
	tuning = TuningDef.load_default()
	plan = ScenarioM2C.SCRIPT_M2C.duplicate(true)
	plan[0].remove_at(0)  # the garage has 2 seats: the owner plus the candidate hired at week 4
	plan[0].remove_at(0)  # the free equipment grant; seat 1 is bought at week 4 instead
	plan[0].append(["take_loan", "BANK", 5000])
	plan[4] = [["hire_candidate"], ["buy_equipment", "equipment_micro_1980", 1], ["accept_contract_work"]]
	plan[56] = [["reply_forum", "apologise"]]
	plan[60] = [["repay_loan_all"]]


func after_all() -> void:
	ContentDB.use(Fixtures.content())


func _new_state(p_seed: int) -> GameState:
	return GameState.new_game(p_seed, "Test Studio", tuning)


func _run(p_seed: int, weeks: int = WEEKS) -> GameState:
	var s := _new_state(p_seed)
	ScenarioM2b.advance(s, plan, weeks, real, tuning)
	return s


func test_combined_playthrough() -> void:
	var s := _run(2026)
	assert_false(s.game_over)
	assert_eq(s.staff.size(), 2)
	assert_eq(s.equipment.size(), 2)
	assert_true(s.loans.is_empty())
	var games: Array[Project] = []
	var jobs := 0
	for id: int in s.sorted_ids(s.projects):
		var p: Project = s.projects[id]
		if p.kind == Project.Kind.CONTRACT_WORK:
			jobs += 1
			assert_eq(p.phase, Project.Phase.RETIRED)
		elif p.kind == Project.Kind.GAME and p.parent_id == -1:
			games.append(p)
	assert_eq(jobs, 1)
	assert_eq(games.size(), 2)
	for g: Project in games:
		assert_eq(g.review_results.size(), 4)
	assert_gte(games[0].weekly_units.size(), 20)
	assert_true(games[1].mod_tools)
	assert_eq(games[1].dlc_count, 1)
	assert_gt(s.companies[s.player_company_id].promo_fatigue, 0)
	var replied := 0
	for f: ForumPost in s.forum_posts:
		if f.replied:
			replied += 1
	assert_gt(replied, 0)
	assert_true(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))
	assert_eq(real.missing_refs(s), [] as Array[String])


func test_same_seed_same_hash() -> void:
	assert_eq(StateHash.of(_run(7)), StateHash.of(_run(7)))


func test_save_load_continue_matches_uninterrupted() -> void:
	var full := StateHash.of(_run(7))
	for save_week: int in [4, 15, 49, 56, 60, 69]:
		var s := _new_state(7)
		ScenarioM2b.advance(s, plan, save_week, real, tuning)
		var loaded := SaveService.deserialize(SaveService.serialize(s))
		assert_true(loaded.ok, "load at %d" % save_week)
		ScenarioM2b.advance(loaded.state, plan, WEEKS - save_week, real, tuning)
		assert_eq(StateHash.of(loaded.state), full, "save at week %d" % save_week)
