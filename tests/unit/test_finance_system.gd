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


func test_ai_company_salaries_do_not_change_money() -> void:
	var s: GameState = Fixtures.new_state(1)
	var ai: int = Fixtures.company_of_kind(s, Company.Kind.AI_PUBLISHER)
	var before: int = s.companies[ai].money
	Fixtures.add_staff(s, {"salary": 500, "company_id": ai})
	s.week = 4
	var ctx := TickContext.new(s, Fixtures.tuning())
	FinanceSystem.tick(ctx)
	assert_eq(s.companies[ai].money, before)
	for ev: Dictionary in ctx.events:
		if ev["name"] == &"money_changed":
			assert_eq(ev["payload"]["company_id"], s.player_company_id)


func test_bought_equipment_not_lease_upgraded() -> void:
	var s: GameState = Fixtures.new_state(1)
	var eid: int = Fixtures.add_equipment(s, {"ownership": Equipment.Ownership.BOUGHT})
	s.week = 520
	FinanceSystem.tick(TickContext.new(s, Fixtures.tuning()))
	assert_eq(s.equipment[eid].def_id, &"equipment_micro_1980")


func test_leased_equipment_does_not_depreciate() -> void:
	var s: GameState = Fixtures.new_state(1)
	var eid: int = Fixtures.add_equipment(s, {"ownership": Equipment.Ownership.LEASED, "value": 1000})
	s.week = 4
	FinanceSystem.tick(TickContext.new(s, Fixtures.tuning()))
	assert_eq(s.equipment[eid].value, 1000)


func test_lease_upgrade_emits_equipment_changed() -> void:
	var s: GameState = Fixtures.new_state(1)
	Fixtures.add_equipment(s, {"ownership": Equipment.Ownership.LEASED})
	s.week = 4
	var ctx := TickContext.new(s, Fixtures.tuning())
	FinanceSystem.tick(ctx)
	var n: int = 0
	for ev: Dictionary in ctx.events:
		if ev["name"] == &"equipment_changed":
			n += 1
	assert_eq(n, 1)
