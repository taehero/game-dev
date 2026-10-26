extends GutTest
## Save, load and autosave wiring on the GameRunner autoload.

var _dir: String = ""


func before_each() -> void:
	_dir = "user://test_runner_saves_%d" % Time.get_ticks_usec()
	Fixtures.new_state(0)
	GameRunner.save_dir = _dir
	GameRunner.session = null


func after_each() -> void:
	GameRunner.session = null
	GameRunner.save_dir = SaveService.DEFAULT_DIR
	var abs_dir: String = ProjectSettings.globalize_path(_dir)
	if DirAccess.dir_exists_absolute(abs_dir):
		for f: String in DirAccess.get_files_at(abs_dir):
			DirAccess.remove_absolute(abs_dir.path_join(f))
		DirAccess.remove_absolute(abs_dir)


func test_save_then_load_round_trips_state() -> void:
	GameRunner.start_new_game(5, "Acme")
	assert_eq(GameRunner.save_game("slot_1"), OK)
	var saved_hash: String = StateHash.of(GameRunner.session.state)
	GameRunner.start_new_game(99, "Other")
	var r: LoadResult = GameRunner.load_game("slot_1")
	assert_true(r.ok)
	assert_eq(StateHash.of(GameRunner.session.state), saved_hash)


func test_load_sets_speed_zero() -> void:
	GameRunner.start_new_game(5, "Acme")
	GameRunner.save_game("slot_1")
	GameRunner.set_speed(2)
	GameRunner.load_game("slot_1")
	assert_eq(GameRunner.session.speed, 0)


func test_save_busy_when_commands_queued() -> void:
	GameRunner.start_new_game(5, "Acme")
	GameRunner.set_speed(1)
	GameRunner.submit(HireStaffCommand.new(GameRunner.session.state.player_company_id, "Ada", 800))
	assert_eq(GameRunner.save_game("slot_1"), ERR_BUSY)
	assert_false(FileAccess.file_exists(_dir.path_join("slot_1.json")))


func test_failed_load_leaves_session_untouched() -> void:
	GameRunner.start_new_game(5, "Acme")
	var before: GameSession = GameRunner.session
	var before_hash: String = StateHash.of(before.state)
	var r: LoadResult = GameRunner.load_game("slot_2")
	assert_false(r.ok)
	assert_same(GameRunner.session, before)
	assert_eq(StateHash.of(GameRunner.session.state), before_hash)


func test_corrupt_slot_load_leaves_session_untouched() -> void:
	GameRunner.start_new_game(5, "Acme")
	var before: GameSession = GameRunner.session
	var before_hash: String = StateHash.of(before.state)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	var f: FileAccess = FileAccess.open(_dir.path_join("slot_2.json"), FileAccess.WRITE)
	f.store_string("{\"schema_version\": 1, \"sta")
	f.close()
	var r: LoadResult = GameRunner.load_game("slot_2")
	assert_false(r.ok)
	assert_eq(r.error_key, &"error.save_unreadable")
	assert_same(GameRunner.session, before)
	assert_eq(StateHash.of(GameRunner.session.state), before_hash)


func test_autosave_written_on_quarter_start() -> void:
	GameRunner.start_new_game(5, "Acme")
	GameRunner.session.state.week = 12
	GameRunner.set_speed(1)
	GameRunner._process(8.0)
	assert_false(GameRunner.session.autosave_due)
	assert_true(FileAccess.file_exists(_dir.path_join("autosave.json")))


func test_autosave_deferred_while_commands_queued() -> void:
	GameRunner.start_new_game(5, "Acme")
	GameRunner.session.autosave_due = true
	GameRunner.set_speed(1)
	GameRunner.submit(HireStaffCommand.new(GameRunner.session.state.player_company_id, "Ada", 800))
	GameRunner._process(0.0)
	assert_true(GameRunner.session.autosave_due)
	assert_false(FileAccess.file_exists(_dir.path_join("autosave.json")))


func test_load_refuses_save_with_unknown_content_id() -> void:
	Fixtures.new_state(0)
	GameRunner.start_new_game(3, "T")
	GameRunner.session.state.companies[GameRunner.session.state.player_company_id].office_id = &"office_gone"
	GameRunner.save_game("slot_1")
	GameRunner.start_new_game(4, "T2")
	var before: String = StateHash.of(GameRunner.session.state)
	var r: LoadResult = GameRunner.load_game("slot_1")
	assert_false(r.ok)
	assert_eq(r.error_key, &"error.save_content_missing")
	assert_eq(StateHash.of(GameRunner.session.state), before)


func test_successful_load_emits_game_loaded() -> void:
	Fixtures.new_state(0)
	GameRunner.start_new_game(3, "T")
	GameRunner.save_game("slot_1")
	watch_signals(EventBus)
	GameRunner.load_game("slot_1")
	GameRunner._process(0.0)
	assert_signal_emitted(EventBus, "game_loaded")


func test_new_game_emits_game_loaded() -> void:
	watch_signals(EventBus)
	GameRunner.start_new_game(3, "T")
	GameRunner._process(0.0)
	assert_signal_emitted(EventBus, "game_loaded")


func test_set_speed_pushes_speed_changed_event() -> void:
	GameRunner.start_new_game(5, "Acme")
	GameRunner.session.drain_events()
	GameRunner.set_speed(4)
	var events: Array[Dictionary] = GameRunner.session.drain_events()
	assert_eq(events.size(), 1)
	assert_eq(events[0]["name"], &"speed_changed")
	assert_eq(events[0]["payload"]["speed"], 4)


func test_pause_and_resume_for_popup_restores_speed() -> void:
	GameRunner.start_new_game(5, "Acme")
	GameRunner.set_speed(4)
	GameRunner.pause_for_popup()
	assert_eq(GameRunner.session.speed, 0)
	GameRunner.resume_after_popup()
	assert_eq(GameRunner.session.speed, 4)


func test_nested_pause_keeps_first_remembered_speed() -> void:
	GameRunner.start_new_game(5, "Acme")
	GameRunner.set_speed(4)
	GameRunner.pause_for_popup()
	GameRunner.pause_for_popup()
	GameRunner.resume_after_popup()
	assert_eq(GameRunner.session.speed, 4)
	GameRunner.resume_after_popup()
	assert_eq(GameRunner.session.speed, 4)


func test_resume_without_pause_does_nothing() -> void:
	GameRunner.start_new_game(5, "Acme")
	GameRunner.resume_after_popup()
	assert_eq(GameRunner.session.speed, 0)
	GameRunner.set_speed(2)
	GameRunner.pause_for_popup()
	GameRunner.set_speed(1)
	GameRunner.resume_after_popup()
	GameRunner.resume_after_popup()
	assert_eq(GameRunner.session.speed, 2)


func test_popup_after_auto_pause_resumes_previous_speed() -> void:
	GameRunner.start_new_game(5, "Acme")
	GameRunner.session.auto_paused_speed = 4
	GameRunner.pause_for_popup()
	assert_eq(GameRunner.session.auto_paused_speed, 0)
	GameRunner.resume_after_popup()
	assert_eq(GameRunner.session.speed, 4)


func test_manual_pause_then_popup_stays_paused() -> void:
	GameRunner.start_new_game(5, "Acme")
	GameRunner.pause_for_popup()
	GameRunner.resume_after_popup()
	assert_eq(GameRunner.session.speed, 0)
