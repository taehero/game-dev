extends GutTest


func test_dispatch_emits_matching_signal() -> void:
	watch_signals(EventBus)
	assert_true(EventBus.dispatch(&"week_ticked", {"week": 1}))
	assert_signal_emitted_with_parameters(EventBus, "week_ticked", [{"week": 1}])


func test_dispatch_unknown_name_returns_false() -> void:
	assert_false(EventBus.dispatch(&"no_such_event", {}))
	assert_push_warning_count(1)
