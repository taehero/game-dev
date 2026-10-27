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
	# the garage has 2 seats: drop the free hire and the free equipment grant; seat 1 is bought at week 4 instead
	plan[0] = plan[0].filter(func(spec: Array) -> bool: return spec[0] != "hire" and spec[0] != "place_equipment")
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
	assert_true(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))
	assert_eq(real.missing_refs(s), [] as Array[String])


func test_forum_reply_and_award_outcome() -> void:
	var s := _new_state(2026)
	ScenarioM2b.advance(s, plan, 49, real, tuning)
	assert_eq(s.week, 49)
	# play the week-49 step by hand (same commands as the plan) so the entry and the ceremony event are observable
	var session := GameSession.new(s, tuning)
	var money_before: int = s.companies[s.player_company_id].money
	var enter: CommandResult = session.submit(ScenarioM2C.make(s, ["enter_award", "award_golden_cartridge"]))
	assert_true(enter.ok, "the week-49 award entry is accepted")
	var entered: Array[int] = []
	for id: int in s.sorted_ids(s.projects):
		if s.projects[id].award_entry == &"award_golden_cartridge":
			entered.append(id)
	assert_eq(entered.size(), 1, "the entry is pending before the ceremony")
	assert_lt(s.companies[s.player_company_id].money, money_before, "the entry fee was paid")
	for spec: Array in plan[49]:
		if spec[0] != "enter_award":
			session.submit(ScenarioM2b._make_command(s, spec))
	session.step_once()  # the ceremony runs in this tick
	var results: Array[Dictionary] = []
	for e: Dictionary in session.drain_events():
		if e["name"] == &"award_result":
			results.append(e["payload"])
	assert_eq(results.size(), 1, "the ceremony fired for the entry")
	if results.size() == 1:
		assert_eq(results[0]["project_id"], entered[0], "the entered game was the one scored")
		# the outcome itself is an RNG result; only require that state agrees with the event
		var awards: Array[StringName] = s.companies[s.player_company_id].awards
		assert_eq(not awards.is_empty(), results[0]["won"], "awards list matches the ceremony result")
	for id: int in s.sorted_ids(s.projects):
		assert_eq(s.projects[id].award_entry, &"", "entry consumed by the ceremony")
	ScenarioM2b.advance(s, plan, 6, real, tuning)
	var target := -1  # the post the week-56 reply_forum step answers: the first unreplied one
	for f: ForumPost in s.forum_posts:
		if not f.replied:
			target = f.id
			break
	assert_ne(target, -1)
	ScenarioM2b.advance(s, plan, 1, real, tuning)
	for f: ForumPost in s.forum_posts:
		if f.id == target:
			assert_true(f.replied)


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
