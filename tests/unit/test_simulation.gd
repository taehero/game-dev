extends GutTest


func test_system_order_matches_spec() -> void:
	assert_eq(Simulation.SYSTEMS, [CalendarSystem, WorldEventSystem, MarketSystem, StaffSystem,
		ProductionSystem, MarketingSystem, SalesSystem, LiveOpsSystem, FinanceSystem])


func test_step_advances_week_and_emits_week_ticked_first() -> void:
	var s: GameState = Fixtures.new_state(1)
	var ctx := TickContext.new(s, Fixtures.tuning())
	Simulation.step(ctx)
	assert_eq(s.week, 1)
	assert_eq(ctx.events[0]["name"], &"week_ticked")
