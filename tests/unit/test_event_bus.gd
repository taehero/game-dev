extends GutTest


func test_dispatch_emits_matching_signal() -> void:
	watch_signals(EventBus)
	assert_true(EventBus.dispatch(&"week_ticked", {"week": 1}))
	assert_signal_emitted_with_parameters(EventBus, "week_ticked", [{"week": 1}])


func test_dispatch_unknown_name_returns_false() -> void:
	assert_false(EventBus.dispatch(&"no_such_event", {}))
	assert_push_warning_count(1)


func test_every_m2_event_has_a_signal() -> void:
	var names: Array[StringName] = [&"points_gained", &"bug_found", &"project_stage_changed", &"research_done",
		&"platform_rumored", &"platform_launched", &"platform_retired", &"raise_requested", &"staff_hired",
		&"staff_fired", &"equipment_changed", &"loan_taken", &"payment_missed", &"repossessed",
		&"contract_offered", &"contract_completed", &"award_result", &"promotion_started", &"game_over",
		&"game_loaded", &"review_published", &"sales_updated"]
	for n: StringName in names:
		assert_true(EventBus.has_signal(n), "missing signal %s" % n)
