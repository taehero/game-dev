extends GutTest


func test_salaries_paid_on_month_start_only() -> void:
	var s: GameState = Fixtures.new_state(1)
	var t: TuningDef = Fixtures.tuning()
	Fixtures.add_staff(s, {"salary": 500})
	Fixtures.add_staff(s, {"salary": 300})
	s.week = 4  # month start (week_in_year 4)
	FinanceSystem.tick(TickContext.new(s, t))
	assert_eq(s.companies[s.player_company_id].money, 20000 - 800 - 30)
	s.week = 5
	FinanceSystem.tick(TickContext.new(s, t))
	assert_eq(s.companies[s.player_company_id].money, 20000 - 800 - 30)


func test_ai_companies_get_no_money_event() -> void:
	var s: GameState = Fixtures.new_state(1)
	Fixtures.add_staff(s, {"salary": 500})
	s.week = 4
	var ctx := TickContext.new(s, Fixtures.tuning())
	FinanceSystem.tick(ctx)
	assert_eq(ctx.events.size(), 1)
	assert_eq(ctx.events[0]["payload"]["company_id"], s.player_company_id)


func test_depreciation() -> void:
	var s: GameState = Fixtures.new_state(1)
	s.week = 4
	FinanceSystem.tick(TickContext.new(s, Fixtures.tuning()))
	var vals: Array[int] = []
	for eid: int in s.equipment:
		vals.append(s.equipment[eid].value)
	assert_true(vals.has(784), "starter 800 -> 784")


func test_lease_upgrade() -> void:
	var s: GameState = Fixtures.new_state(1)
	var eid: int = Fixtures.add_equipment(s, {"ownership": Equipment.Ownership.LEASED})
	s.week = 4
	FinanceSystem.tick(TickContext.new(s, Fixtures.tuning()))
	assert_eq(s.equipment[eid].def_id, &"equipment_fx_fast")
	s.week = 520
	FinanceSystem.tick(TickContext.new(s, Fixtures.tuning()))
	assert_eq(s.equipment[eid].def_id, &"equipment_fx_future")
