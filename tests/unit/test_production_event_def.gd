extends GutTest


func test_option_effects_by_index() -> void:
	var ev: ProductionEventDef = Fixtures.pevent(&"pevent_fx_a", {&"bugs": 3}, {&"hype": 2}, {&"morale": 1})
	assert_eq(ev.option_effects(0), {&"bugs": 3})
	assert_eq(ev.option_effects(1), {&"hype": 2})
	assert_eq(ev.option_effects(2), {&"morale": 1})
	assert_eq(ev.option_effects(3), {})


func test_content_db_indexes_events() -> void:
	var db: ContentDB = Fixtures.content_plus([Fixtures.pevent(&"pevent_fx_a", {&"bugs": 3}, {})] as Array[Resource])
	assert_true(db.production_events.has(&"pevent_fx_a"))
	assert_false(db.awards.has(&"pevent_fx_a"))


func _errors_for(ev: ProductionEventDef) -> Array[String]:
	return Fixtures.content_plus([ev] as Array[Resource]).validate()


func test_validate_flags_bad_events() -> void:
	var bad_prefix: Array[String] = _errors_for(Fixtures.pevent(&"event_x", {&"bugs": 1}, {}))
	assert_eq(bad_prefix.size(), 1)
	assert_string_contains(bad_prefix[0], "event_x")

	var one_option: ProductionEventDef = Fixtures.pevent(&"pevent_fx_one", {&"bugs": 1}, {})
	one_option.option_keys = [&"event.fx.option.1"] as Array[StringName]
	var e1: Array[String] = _errors_for(one_option)
	assert_eq(e1.size(), 1)
	assert_string_contains(e1[0], "pevent_fx_one")

	var e2: Array[String] = _errors_for(Fixtures.pevent(&"pevent_fx_money", {&"money": 5}, {}))
	assert_eq(e2.size(), 1)
	assert_string_contains(e2[0], "pevent_fx_money")

	var e3: Array[String] = _errors_for(Fixtures.pevent(&"pevent_fx_big", {&"bugs": 21}, {}))
	assert_eq(e3.size(), 1)
	assert_string_contains(e3[0], "pevent_fx_big")

	var stray_c: ProductionEventDef = Fixtures.pevent(&"pevent_fx_c", {&"bugs": 1}, {})
	stray_c.option_c = {&"hype": 1, &"morale": 1}
	var e4: Array[String] = _errors_for(stray_c)
	assert_eq(e4.size(), 1)
	assert_string_contains(e4[0], "pevent_fx_c")


func test_valid_event_has_no_errors() -> void:
	assert_eq(_errors_for(Fixtures.pevent(&"pevent_fx_ok", {&"bugs": -3, &"progress_bp": 500}, {&"hype": 5}, {&"design": 40})).size(), 0)
