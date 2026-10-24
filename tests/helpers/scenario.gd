class_name Scenario
extends RefCounted
## Test helper: drives a paused GameSession through a scripted command timeline.

## week -> list of command specs.
const SCRIPT_BASIC: Dictionary = {
	0: [["hire", "Ada", 800]],
	10: [["hire", "Bo", 700]],
	30: [["hire", "Cy", 900]],
	200: [["hire", "Di", 600]],
}


static func advance(state: GameState, script: Dictionary, weeks: int) -> void:
	var session := GameSession.new(state, Fixtures.tuning())
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
			return HireStaffCommand.new(state.player_company_id, spec[1], spec[2])
	push_error("Scenario: unknown command spec %s" % str(spec))
	assert(false, "Scenario unknown command")
	return null
