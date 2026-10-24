extends Node
## Autoload "GameRunner". No class_name: it would hide the autoload.

var session: GameSession


func start_new_game(p_seed: int, studio_name: String) -> void:
	var tuning: TuningDef = load("res://data/tuning.tres") as TuningDef
	session = GameSession.new(GameState.new_game(p_seed, studio_name, tuning), tuning)


func submit(cmd: Command) -> CommandResult:
	return session.submit(cmd)


func set_speed(s: int) -> void:
	session.set_speed(s)


func _process(delta: float) -> void:
	if session == null:
		return
	session.advance(delta)
	for e: Dictionary in session.drain_events():
		EventBus.dispatch(e["name"], e["payload"])
