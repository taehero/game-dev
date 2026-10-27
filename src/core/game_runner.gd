extends Node
## Autoload "GameRunner". No class_name: it would hide the autoload.

var session: GameSession
## Overridden by tests so they never touch the real user saves.
var save_dir: String = SaveService.DEFAULT_DIR

## Speed to restore after a popup pause; 0 means nothing remembered.
var _popup_resume_speed: int = 0


func start_new_game(p_seed: int, studio_name: String) -> void:
	var tuning: TuningDef = TuningDef.load_default()
	session = GameSession.new(GameState.new_game(p_seed, studio_name, tuning), tuning)
	_popup_resume_speed = 0
	session.push_event(&"game_loaded", {})


func submit(cmd: Command) -> CommandResult:
	return session.submit(cmd)


func set_speed(s: int) -> void:
	session.set_speed(s)
	session.push_event(&"speed_changed", {"speed": session.speed})


## A popup freezes the clock. The first call remembers the running speed; nested calls keep it.
func pause_for_popup() -> void:
	if session == null:
		return
	if session.speed > 0:
		_popup_resume_speed = session.speed
		set_speed(0)
	elif session.auto_paused_speed > 0 and _popup_resume_speed == 0:
		_popup_resume_speed = session.auto_paused_speed
	session.auto_paused_speed = 0


func resume_after_popup() -> void:
	if session == null or _popup_resume_speed == 0:
		return
	var s: int = _popup_resume_speed
	_popup_resume_speed = 0
	set_speed(s)


func save_game(slot: String) -> Error:
	if not session.can_save():
		return ERR_BUSY
	return SaveService.save_to_slot(session.state, slot, save_dir)


## True when `slot` is a valid slot and its file exists under save_dir.
func has_save(slot: String) -> bool:
	return SaveService.is_valid_slot(slot) and FileAccess.file_exists(save_dir.path_join(slot + ".json"))


func load_game(slot: String) -> LoadResult:
	var r: LoadResult = SaveService.load_from_slot(slot, save_dir)
	if not r.ok:
		return r
	if not ContentDB.active().missing_refs(r.state).is_empty():
		return LoadResult.failure(&"error.save_content_missing")
	var tuning: TuningDef = TuningDef.load_default()
	session = GameSession.new(r.state, tuning)
	_popup_resume_speed = 0
	session.set_speed(0)
	session.push_event(&"game_loaded", {})
	return r


func _process(delta: float) -> void:
	if session == null:
		return
	session.advance(delta)
	if session.autosave_due and session.can_save():
		session.autosave_due = false
		if not session.state.game_over and save_game("autosave") != OK:
			push_warning("GameRunner: autosave failed")
	for e: Dictionary in session.drain_events():
		EventBus.dispatch(e["name"], e["payload"])
