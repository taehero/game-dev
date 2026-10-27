extends GutTest

var s: GameState


func before_each() -> void:
	s = Fixtures.new_state(1)
	s.week = 4


func _tick() -> TickContext:
	var ctx := TickContext.new(s, Fixtures.tuning())
	FinanceSystem.tick(ctx)
	return ctx


func test_monthly_payment() -> void:
	var id: int = Fixtures.add_loan(s)
	_tick()
	assert_eq(s.loans[id].balance, 4791)
	assert_eq(s.loans[id].missed_payments, 0)
	assert_eq(s.companies[1].money, 20000 - 30 - 259)


func test_final_payment_removes_loan() -> void:
	var id: int = Fixtures.add_loan(s, {"balance": 100})
	_tick()
	assert_false(s.loans.has(id))
	assert_eq(s.companies[1].money, 20000 - 30 - 101)


func test_negative_money_misses_every_loan() -> void:
	s.companies[1].money = -100
	var a: int = Fixtures.add_loan(s)
	var b: int = Fixtures.add_loan(s)
	var ctx := _tick()
	assert_eq(s.companies[1].money, -130)
	for id: int in [a, b]:
		assert_eq(s.loans[id].missed_payments, 1)
		assert_eq(s.loans[id].balance, 5050)
	assert_eq(s.companies[1].last_missed_week, 4)
	var n: int = 0
	for e: Dictionary in ctx.events:
		if e["name"] == &"payment_missed":
			n += 1
	assert_eq(n, 2)


func test_paid_month_resets_missed_below_seize_threshold() -> void:
	var id: int = Fixtures.add_loan(s, {"missed_payments": 1})
	_tick()
	assert_eq(s.loans[id].missed_payments, 0)


func test_paid_month_keeps_missed_at_seize_threshold() -> void:
	var id: int = Fixtures.add_loan(s, {"missed_payments": 3})
	_tick()
	assert_eq(s.loans[id].missed_payments, 3)


func test_second_loan_paid_after_first_goes_negative() -> void:
	s.companies[1].money = 130
	var a: int = Fixtures.add_loan(s)
	var b: int = Fixtures.add_loan(s)
	_tick()
	assert_eq(s.companies[1].money, 130 - 30 - 259 - 259)
	for id: int in [a, b]:
		assert_eq(s.loans[id].missed_payments, 0)
		assert_eq(s.loans[id].balance, 4791)
