class_name Scenario
extends RefCounted
## Test helper: drives a paused GameSession through a scripted command timeline.

## week -> list of command specs.
const SCRIPT_BASIC: Dictionary = {
	0: [["hire", "Ada"]],
}


const SCRIPT_M2A: Dictionary = {
	0: [["hire", "Ada"], ["place_equipment", "equipment_micro_1980", 1],
		["start_game", "Star Run", "size_small", "platform_nova8", "topic_space", "genre_action", "lic_engine_homebrew", []],
		["sliders_ideal"]],
	20: [["release"]],
	22: [["buy_research", "research_scrolling"], ["start_engine", "Scroll Engine", ["feature_scrolling"]]],
	28: [["buy_dev_kit", "platform_arcadia"],
		["start_game", "Kick Arena", "size_small", "platform_arcadia", "topic_sports", "genre_action", "last_engine", ["feature_scrolling"]],
		["sliders_ideal"]],
	48: [["release"]],
}


static func advance(state: GameState, script: Dictionary, weeks: int, content: ContentDB = null, tuning: TuningDef = null) -> void:
	if content != null:
		ContentDB.use(content)
	var session := GameSession.new(state, tuning if tuning != null else Fixtures.tuning())
	for i: int in weeks:
		if script.has(state.week):
			for spec: Array in script[state.week]:
				var cmd: Command = _make_command(state, spec)
				var result: CommandResult = session.submit(cmd)
				if not result.ok:
					push_error("Scenario: command %s rejected at week %d: %s" % [str(spec), state.week, result.reason_key])
					assert(false, "Scenario command rejected")
		session.step_once()


static func run(state: GameState, script: Dictionary, weeks: int) -> String:
	advance(state, script, weeks)
	return StateHash.of(state)


static func _make_command(state: GameState, spec: Array) -> Command:
	match spec[0]:
		"hire":
			# optional third element overrides the salary; default is the market offer from tuning
			var salary: int = spec[2] if spec.size() > 2 else Fixtures.tuning().hire_offer_salary
			return HireStaffCommand.new(state.player_company_id, spec[1], salary)
		"place_equipment":
			return PlaceEquipmentCommand.new(state.player_company_id, StringName(spec[1]), spec[2])
		"start_game":
			var engine_id: int = -1
			var licensed: StringName = &""
			if spec[6] == "last_engine":
				for eid: int in state.sorted_ids(state.engines):
					engine_id = eid
			else:
				licensed = StringName(spec[6])
			var feats: Array[StringName] = []
			for f: String in spec[7]:
				feats.append(StringName(f))
			return StartProjectCommand.game(state.player_company_id, spec[1], StringName(spec[2]), StringName(spec[3]), StringName(spec[4]), StringName(spec[5]), engine_id, licensed, feats)
		"start_engine":
			var efeats: Array[StringName] = []
			for f: String in spec[2]:
				efeats.append(StringName(f))
			return StartProjectCommand.engine(state.player_company_id, spec[1], efeats)
		"sliders_ideal":
			var pid: int = _latest_game(state, Project.Phase.PRODUCTION)
			var genre: GenreDef = ContentDB.active().genres[state.projects[pid].config[&"genre"]]
			var ideal: Array[int] = []
			ideal.assign(genre.ideal_sliders)
			return SetSlidersCommand.new(pid, ideal)
		"release":
			return ReleaseProjectCommand.new(_latest_game(state, Project.Phase.POLISH))
		"buy_research":
			return BuyResearchCommand.new(state.player_company_id, StringName(spec[1]))
		"buy_dev_kit":
			return BuyDevKitCommand.new(state.player_company_id, StringName(spec[1]))
	var ext: Command = ScenarioM2C.make(state, spec)
	if ext != null:
		return ext
	push_error("Scenario: unknown command spec %s" % str(spec))
	assert(false, "Scenario unknown command")
	return null


static func _latest_game(state: GameState, phase: Project.Phase) -> int:
	var found: int = -1
	for id: int in state.sorted_ids(state.projects):
		var p: Project = state.projects[id]
		if p.kind == Project.Kind.GAME and p.phase == phase:
			found = id
	return found
