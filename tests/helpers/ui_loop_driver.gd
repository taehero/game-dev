class_name UiLoopDriver
extends RefCounted
## Test helper: plays the loop through the same commands the UI sends, state-driven so it resumes after a load.

const GAME_ONE: String = "Star Run"
const GAME_TWO: String = "Kick Arena"
const ENGINE_NAME: String = "Scroll Engine"

## Messages for every rejected command or unoffered engine; the scenario asserts it stays empty.
static var failures: Array[String] = []


## Shipped tuning with a production event every eligible week (P22).
static func tuning() -> TuningDef:
	var t: TuningDef = TuningDef.load_default().duplicate()
	t.production_event_chance_bp = 10000
	return t


## Runs `weeks` weeks (actions then one tick each); returns the total events answered.
static func advance(session: GameSession, weeks: int) -> int:
	var answered: int = 0
	for i: int in weeks:
		answered += week_actions(session)
		session.step_once()
	return answered


## The policy for one week boundary; returns the number of events answered.
static func week_actions(session: GameSession) -> int:
	var state: GameState = session.state
	var content: ContentDB = ContentDB.active()
	var answered: int = 0
	for did: int in StateQueries.pending_event_ids(state, content):
		_send(session, ChooseEventOptionCommand.new(did, 0))
		answered += 1
	var pid: int = StateQueries.active_project_id(state)
	if pid != -1:
		var p: Project = state.projects[pid]
		if p.kind == Project.Kind.GAME and p.phase == Project.Phase.POLISH:
			if StateQueries.project_detail(state, pid)["can_bug_hunt"]:
				_send(session, SubmitBugHuntCommand.new(pid, 6))
			_send(session, ReleaseProjectCommand.new(pid))
		return answered
	_start_next(session, content)
	return answered


static func _start_next(session: GameSession, content: ContentDB) -> void:
	var state: GameState = session.state
	var company_id: int = state.player_company_id
	var company: Company = state.companies[company_id]
	var released: int = 0
	for id: int in state.sorted_ids(state.projects):
		var p: Project = state.projects[id]
		if p.company_id == company_id and p.kind == Project.Kind.GAME and p.phase >= Project.Phase.RELEASED:
			released += 1
	var built_engine: int = -1
	for eid: int in state.sorted_ids(state.engines):
		if state.engines[eid].company_id == company_id:
			built_engine = eid
	var scrolling: Array[StringName] = [&"feature_scrolling"]
	var no_features: Array[StringName] = []
	if released == 0:
		_start_game(session, content, GAME_ONE, &"platform_nova8", &"topic_space", -1, &"lic_engine_homebrew", no_features)
	elif built_engine == -1:
		var rp: int = content.research[&"research_scrolling"].cost_rp
		if not company.unlocked.has(&"research_scrolling"):
			if company.research_points < rp:
				return
			_send(session, BuyResearchCommand.new(company_id, &"research_scrolling"))
		_send(session, StartProjectCommand.engine(company_id, ENGINE_NAME, scrolling))
	elif released == 1:
		if not company.dev_kits.has(&"platform_arcadia"):
			_send(session, BuyDevKitCommand.new(company_id, &"platform_arcadia"))
		if StateQueries.staff_count(state, company_id) == 1:
			_send(session, HireStaffCommand.new(company_id, "Ada", session.tuning.hire_offer_salary))
		_start_game(session, content, GAME_TWO, &"platform_arcadia", &"topic_sports", built_engine, &"", scrolling)


## Starts a game (the engine pair must be one the concept options offer), then sets the genre's ideal sliders.
static func _start_game(session: GameSession, content: ContentDB, title: String, platform_id: StringName, topic_id: StringName, engine_id: int, licensed_id: StringName, features: Array[StringName]) -> void:
	var state: GameState = session.state
	var genre_id: StringName = &"genre_action"
	var offered: bool = false
	for entry: Dictionary in StateQueries.concept_options(state, content, session.tuning)["engines"]:
		if entry["engine_id"] == engine_id and entry["licensed_id"] == licensed_id:
			offered = true
	if not offered:
		var msg: String = "engine (%d, %s) not offered by concept_options" % [engine_id, licensed_id]
		push_error("UiLoopDriver: " + msg)
		failures.append(msg)
	var cmd := StartProjectCommand.game(state.player_company_id, title, &"size_small", platform_id, topic_id, genre_id, engine_id, licensed_id, features)
	_send(session, cmd)
	var pid: int = StateQueries.active_project_id(state)
	var ideal: Array[int] = []
	ideal.assign(content.genres[genre_id].ideal_sliders)
	_send(session, SetSlidersCommand.new(pid, ideal))


static func _send(session: GameSession, cmd: Command) -> void:
	var result: CommandResult = session.submit(cmd)
	if not result.ok:
		var msg: String = "%s rejected at week %d: %s" % [cmd.get_class(), session.state.week, result.reason_key]
		push_error("UiLoopDriver: " + msg)
		failures.append(msg)
