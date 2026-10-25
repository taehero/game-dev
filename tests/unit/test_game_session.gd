extends GutTest


func _session() -> GameSession:
	return GameSession.new(Fixtures.new_state(1), Fixtures.tuning())


func test_paused_does_not_tick() -> void:
	var g := _session()
	assert_eq(g.advance(100.0), 0)
	assert_eq(g.state.week, 0)


func test_one_week_per_8_seconds_at_1x() -> void:
	var g := _session()
	g.set_speed(1)
	assert_eq(g.advance(7.9), 0)
	assert_eq(g.advance(0.2), 1)
	assert_eq(g.state.week, 1)


func test_4x_runs_four_times_faster() -> void:
	var g := _session()
	g.set_speed(4)
	assert_eq(g.advance(2.0), 1)


func test_huge_delta_is_capped_and_remainder_dropped() -> void:
	var g := _session()
	g.set_speed(4)
	assert_eq(g.advance(3600.0), 4)
	assert_eq(g.advance(0.0), 0)


func test_invalid_speed_ignored() -> void:
	var g := _session()
	g.set_speed(3)
	assert_eq(g.speed, 0)
	assert_push_warning_count(1)


func test_command_applies_immediately_when_paused() -> void:
	var g := _session()
	g.submit(HireStaffCommand.new(g.state.player_company_id, "Ada", 800))
	assert_eq(g.state.staff.size(), 2)


func test_command_waits_for_next_tick_when_running() -> void:
	var g := _session()
	g.set_speed(1)
	g.submit(HireStaffCommand.new(g.state.player_company_id, "Ada", 800))
	assert_eq(g.state.staff.size(), 1)
	assert_false(g.can_save())
	g.advance(8.0)
	assert_eq(g.state.staff.size(), 2)
	assert_true(g.can_save())


func test_rejected_command_emits_event() -> void:
	var g := _session()
	var r := g.submit(HireStaffCommand.new(999, "X", 800))
	assert_false(r.ok)
	assert_eq(g.drain_events()[0]["name"], &"command_rejected")


func test_new_decision_auto_pauses() -> void:
	var g := _session()
	g.set_speed(1)
	g.submit(AddDecisionCommand.new())
	g.advance(16.0)
	assert_eq(g.speed, 0)
	assert_eq(g.state.week, 1)
	var names: Array = g.drain_events().map(func(e: Dictionary) -> StringName: return e["name"])
	assert_has(names, &"decision_required")


func test_autosave_due_on_quarter_start() -> void:
	var g := _session()
	g.state.week = 12
	g.set_speed(1)
	g.advance(8.0)
	assert_true(g.autosave_due)


func test_drain_events_clears() -> void:
	var g := _session()
	g.submit(HireStaffCommand.new(999, "X", 800))
	assert_eq(g.drain_events().size(), 1)
	assert_eq(g.drain_events().size(), 0)
