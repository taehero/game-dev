extends GutTest
## Economy feel guard: a good and a poor scripted player run 52 weeks through real commands on shipped data.
## The bands are the measured week-52 values (seed 7, matching the balance sim) with a +/-15% margin, so a later
## tuning change that makes the early game trivial (poor player never in debt) or crushing (good player broke)
## fails here. Measured at retune: good money 14480; poor money 15650 with 21874 of loans outstanding.
const SEED: int = 7
const WEEKS: int = 52
const GOOD_MONEY: Vector2i = Vector2i(12300, 16650)
const POOR_MONEY: Vector2i = Vector2i(13300, 18000)
const POOR_DEBT: Vector2i = Vector2i(18600, 25150)
var _real: ContentDB
var _t: TuningDef


func before_all() -> void:
	_real = ContentDB.load_dir()
	ContentDB.use(_real)
	_t = TuningDef.load_default()


func after_all() -> void:
	ContentDB.use(Fixtures.content())


func _play(good: bool) -> GameSession:
	var session := GameSession.new(GameState.new_game(SEED, "Guard", _t), _t)
	var combo: Array = _combo(session.state, good)
	var ideal: Array[int] = []
	ideal.assign(_real.genres[combo[0]].ideal_sliders)
	var sloppy: Array[int] = [10000, 0, 0, 10000, 0, 0, 10000, 0, 0]
	for i: int in WEEKS:
		_week(session, combo, ideal if good else sloppy, good)
		session.step_once()
	return session


## Best (good) or worst (poor) genre and topic on the Nova 8 by fit; ties keep the first in sorted order.
func _combo(state: GameState, best: bool) -> Array:
	var pick: Array = []
	var pick_fit: int = -1 if best else 1 << 40
	for g: StringName in GameState.sorted_names(_real.genres):
		for tp: StringName in GameState.sorted_names(_real.topics):
			if not (GameRules.is_unlocked(state, _real, state.player_company_id, g) and GameRules.is_unlocked(state, _real, state.player_company_id, tp)):
				continue
			var fit: int = _real.topics[tp].genre_fit_bp.get(g, 10000) * _real.platforms[&"platform_nova8"].genre_fit_bp.get(g, 10000)
			if (best and fit > pick_fit) or (not best and fit < pick_fit):
				pick_fit = fit
				pick = [g, tp]
	return pick


func _week(session: GameSession, combo: Array, sliders: Array[int], good: bool) -> void:
	var st: GameState = session.state
	var cid: int = st.player_company_id
	var co: Company = st.companies[cid]
	for did: int in StateQueries.pending_event_ids(st, _real):
		session.submit(ChooseEventOptionCommand.new(did, 0))
	for sid: int in st.sorted_ids(st.staff):
		if AnswerRaiseCommand.find_ask(st, sid) != null:
			session.submit(AnswerRaiseCommand.new(sid, true))
	if not good and co.money < 3000:
		for lender: int in st.sorted_ids(st.companies):
			if [Company.Kind.BANK, Company.Kind.LENDER].has(st.companies[lender].kind):
				var credit: int = MoneyRules.available_credit(st, cid, lender, _t)
				if credit > 0:
					session.submit(TakeLoanCommand.new(cid, lender, credit))
	var pid: int = StateQueries.active_project_id(st)
	if pid != -1:
		if st.projects[pid].phase == Project.Phase.POLISH:
			if good and StateQueries.project_detail(st, pid)["can_bug_hunt"]:
				session.submit(SubmitBugHuntCommand.new(pid, 6))
			session.submit(ReleaseProjectCommand.new(pid))
		return
	if good and not co.unlocked.has(&"research_size_medium") and co.research_points >= _real.research[&"research_size_medium"].cost_rp:
		session.submit(BuyResearchCommand.new(cid, &"research_size_medium"))
	if StateQueries.staff_count(st, cid) < 2 and co.money >= _t.hire_offer_salary * 4:
		session.submit(HireStaffCommand.new(cid, "Ada", _t.hire_offer_salary))
	var kit: StringName = &"equipment_micro_1980"
	for sid: int in st.sorted_ids(st.staff):
		var seat: int = st.staff[sid].seat_index
		if seat >= 0 and GameRules.equipment_at_seat(st, cid, seat) == -1:
			if co.money >= _real.equipment[kit].price + 3000:
				session.submit(BuyEquipmentCommand.new(cid, kit, seat))
			else:
				session.submit(LeaseEquipmentCommand.new(cid, kit, seat))
	var no_features: Array[StringName] = []
	var size: StringName = &"size_small"
	if good and GameRules.is_unlocked(st, _real, cid, &"size_medium") and GameRules.free_workers(st, cid).size() >= 2 and co.money >= 4000:
		size = &"size_medium"
	var started: CommandResult = session.submit(StartProjectCommand.game(cid, "G%d" % st.week, size, &"platform_nova8", combo[1], combo[0], -1, &"lic_engine_homebrew", no_features))
	if started.ok:
		session.submit(SetSlidersCommand.new(StateQueries.active_project_id(st), sliders))


func _debt(st: GameState) -> int:
	var total: int = 0
	for lid: int in st.sorted_ids(st.loans):
		total += st.loans[lid].balance
	return total


func test_good_player_is_comfortable_at_week_52() -> void:
	var st: GameState = _play(true).state
	var money: int = st.companies[st.player_company_id].money
	assert_false(st.game_over)
	assert_between(money, GOOD_MONEY.x, GOOD_MONEY.y, "good player money at week 52")
	assert_eq(_debt(st), 0, "good player never needs a loan")


func test_poor_player_is_underwater_at_week_52() -> void:
	var st: GameState = _play(false).state
	var money: int = st.companies[st.player_company_id].money
	assert_between(money, POOR_MONEY.x, POOR_MONEY.y, "poor player money at week 52 (borrowed)")
	assert_between(_debt(st), POOR_DEBT.x, POOR_DEBT.y, "poor player debt at week 52")
