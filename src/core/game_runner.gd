extends Node
## Autoload "GameRunner". No class_name: it would hide the autoload.

var session: GameSession
## Overridden by tests so they never touch the real user saves.
var save_dir: String = SaveService.DEFAULT_DIR


func start_new_game(p_seed: int, studio_name: String) -> void:
	var tuning: TuningDef = TuningDef.load_default()
	session = GameSession.new(GameState.new_game(p_seed, studio_name, tuning), tuning)


func submit(cmd: Command) -> CommandResult:
	return session.submit(cmd)


func set_speed(s: int) -> void:
	session.set_speed(s)


func save_game(slot: String) -> Error:
	if not session.can_save():
		return ERR_BUSY
	return SaveService.save_to_slot(session.state, slot, save_dir)


func load_game(slot: String) -> LoadResult:
	var r: LoadResult = SaveService.load_from_slot(slot, save_dir)
	if not r.ok:
		return r
	if not ContentDB.active().missing_refs(r.state).is_empty():
		return LoadResult.failure(&"error.save_content_missing")
	var tuning: TuningDef = TuningDef.load_default()
	session = GameSession.new(r.state, tuning)
	session.set_speed(0)
	session.push_event(&"game_loaded", {})
	return r


func _process(delta: float) -> void:
	if session == null:
		return
	session.advance(delta)
	if session.autosave_due and session.can_save():
		session.autosave_due = false
		if save_game("autosave") != OK:
			push_warning("GameRunner: autosave failed")
	for e: Dictionary in session.drain_events():
		EventBus.dispatch(e["name"], e["payload"])
