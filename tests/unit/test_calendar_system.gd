extends GutTest


func test_tick_advances_week_and_emits_event() -> void:
	var s: GameState = Fixtures.new_state(1)
	var ctx := TickContext.new(s, Fixtures.tuning())
	CalendarSystem.tick(ctx)
	assert_eq(s.week, 1)
	assert_eq(ctx.events.size(), 1)
	assert_eq(ctx.events[0]["name"], &"week_ticked")
	assert_eq(ctx.events[0]["payload"], {"week": 1})
