extends GutTest


func test_emit_appends_name_and_payload_in_order() -> void:
	var ctx := TickContext.new(Fixtures.new_state(1), Fixtures.tuning())
	ctx.emit(&"a", {"x": 1})
	ctx.emit(&"b")
	assert_eq(ctx.events.size(), 2)
	assert_eq(ctx.events[0], {"name": &"a", "payload": {"x": 1}})
	assert_eq(ctx.events[1], {"name": &"b", "payload": {}})


func test_rng_is_state_rng() -> void:
	var s := Fixtures.new_state(1)
	var ctx := TickContext.new(s, Fixtures.tuning())
	assert_same(ctx.rng, s.rng)
