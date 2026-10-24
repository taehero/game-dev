extends GutTest


func test_salaries_paid_on_month_start_only() -> void:
	var s: GameState = Fixtures.new_state(1)
	var t: TuningDef = Fixtures.tuning()
	Fixtures.add_staff(s, {"salary": 500})
	Fixtures.add_staff(s, {"salary": 300})
	s.week = 4  # month start (week_in_year 4)
	FinanceSystem.tick(TickContext.new(s, t))
	assert_eq(s.companies[s.player_company_id].money, 20000 - 800)
	s.week = 5
	FinanceSystem.tick(TickContext.new(s, t))
	assert_eq(s.companies[s.player_company_id].money, 19200)


func test_no_money_event_when_no_salaries() -> void:
	var s: GameState = Fixtures.new_state(1)
	s.week = 4
	var ctx := TickContext.new(s, Fixtures.tuning())
	FinanceSystem.tick(ctx)
	assert_eq(ctx.events.size(), 0)
