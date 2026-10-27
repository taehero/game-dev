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


func _run(p_seed: int, weeks: int = WEEKS) -> GameState:
	var s := _new_state(p_seed)
	ScenarioM2b.advance(s, ScenarioM2b.SCRIPT_M2B, weeks, real, tuning)
	return s


func _by_kind(s: GameState, kind: Project.Kind) -> Array[Project]:
	var out: Array[Project] = []
	for id: int in s.sorted_ids(s.projects):
		if s.projects[id].kind == kind:
			out.append(s.projects[id])
	return out


func test_playthrough_reaches_every_m2b_milestone() -> void:
	var s := _run(2026)
	assert_eq(s.staff.size(), 2)
	assert_eq(s.equipment.size(), 2)
	assert_true(s.loans.is_empty())
	assert_eq(s.owner.perks.get(&"perk_coder", 0), 1)
	assert_false(s.game_over)
	var jobs := _by_kind(s, Project.Kind.CONTRACT_WORK)
	assert_eq(jobs.size(), 1)
	assert_eq(jobs[0].phase, Project.Phase.RETIRED)
	var contract: Contract = s.contracts[jobs[0].contract_id]
	assert_eq(jobs[0].revenue, contract.price)
	var games := _by_kind(s, Project.Kind.GAME)
	assert_eq(games.size(), 1)
	assert_eq(games[0].review_results.size(), 4)
	assert_gte(games[0].weekly_units.size(), 20)
	for c: Candidate in s.candidates:
		assert_gt(c.expires_week, s.week)
	assert_true(GameState.validate_dict(Fixtures.json_round_trip(s.to_dict())))
	assert_eq(real.missing_refs(s), [] as Array[String])


func test_loan_open_mid_run() -> void:
	var s := _run(2026, 20)
	assert_eq(s.loans.size(), 1)
	var l: Loan = s.loans.values()[0]
	assert_eq(s.companies[l.lender_id].kind, Company.Kind.BANK)
	assert_lt(l.balance, 5000)


func test_same_seed_same_hash() -> void:
	assert_eq(StateHash.of(_run(7)), StateHash.of(_run(7)))


func test_different_seed_different_hash() -> void:
	assert_ne(StateHash.of(_run(7)), StateHash.of(_run(8)))


func test_save_load_continue_matches_uninterrupted() -> void:
	var full := StateHash.of(_run(7))
	for save_week: int in [0, 4, 13, 16, 30, 36, 40, 60]:
		var s := _new_state(7)
		ScenarioM2b.advance(s, ScenarioM2b.SCRIPT_M2B, save_week, real, tuning)
		var loaded := SaveService.deserialize(SaveService.serialize(s))
		assert_true(loaded.ok, "load at %d" % save_week)
		ScenarioM2b.advance(loaded.state, ScenarioM2b.SCRIPT_M2B, WEEKS - save_week, real, tuning)
		assert_eq(StateHash.of(loaded.state), full, "save at week %d" % save_week)


func test_values_stay_in_range() -> void:
	var s := _run(7)
	for id: int in s.sorted_ids(s.staff):
		var st: Staff = s.staff[id]
		assert_between(st.morale, 0, 100)
		assert_between(st.burnout, 0, 100)
		for k: StringName in st.skills:
			assert_between(st.skills[k], 1, 100)
	for id: int in s.loans:
		assert_gte(s.loans[id].balance, 0)


func test_bankruptcy_path() -> void:
	var s := _new_state(3)
	s.companies[s.player_company_id].money = -40000
	s.companies[s.player_company_id].last_missed_week = 0
	var lender: int = -1
	for id: int in s.sorted_ids(s.companies):
		if s.companies[id].kind == Company.Kind.LENDER:
			lender = id
	Fixtures.add_loan(s, {"lender_id": lender, "balance": tuning.shark_limit, "principal": tuning.shark_limit,
		"rate_bp_per_month": tuning.shark_rate_bp_per_month, "payment_per_month": 650})
	ScenarioM2b.advance(s, {}, 30, real, tuning)
	assert_true(s.game_over)
	var week: int = s.week
	ScenarioM2b.advance(s, {}, 5, real, tuning)
	assert_eq(s.week, week)


func test_survival_with_shark_loan() -> void:
	var s := _new_state(3)
	s.companies[s.player_company_id].money = -3000
	ScenarioM2b.advance(s, {0: [["take_loan", "LENDER", 8000]]}, 20, real, tuning)
	assert_false(s.game_over)
	assert_eq(s.companies[s.player_company_id].months_negative, 0)
	assert_gte(s.companies[s.player_company_id].money, 0)
