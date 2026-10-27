extends GutTest

var s: GameState


func before_each() -> void:
	s = Fixtures.new_state(1)
	s.week = 4


func _tick() -> TickContext:
	var ctx := TickContext.new(s, Fixtures.tuning())
	FinanceSystem.tick(ctx)
	return ctx


func _shark(overrides: Dictionary = {}) -> int:
	var o: Dictionary = {
		"lender_id": Fixtures.company_of_kind(s, Company.Kind.LENDER),
		"balance": 1000, "principal": 1000, "rate_bp_per_month": 800, "payment_per_month": 42,
	}
	o.merge(overrides, true)
	return Fixtures.add_loan(s, o)


func _count(ctx: TickContext, n: StringName) -> int:
	var c: int = 0
	for e: Dictionary in ctx.events:
		if e["name"] == n:
			c += 1
	return c


func test_repossession_takes_oldest_until_covered() -> void:
	var id: int = _shark()
	var starter: int = s.equipment.keys()[0]
	var other: int = Fixtures.add_equipment(s, {"bought_week": 2, "value": 1500})
	var p: Company = s.companies[1]
	p.money = -500
	p.reputation = 10
	var staff_id: int = Fixtures.add_staff(s, {"morale": 70})
	var ctx := _tick()
	assert_false(s.equipment.has(starter))
	assert_true(s.equipment.has(other))
	assert_eq(s.loans[id].balance, 958)
	assert_eq(s.loans[id].missed_payments, 1)
	assert_eq(p.reputation, 5)
	assert_eq(s.staff[staff_id].morale, 60)
	assert_eq(_count(ctx, &"repossessed"), 1)


func test_leased_never_repossessed() -> void:
	_shark()
	for eid: int in s.equipment.keys():
		s.equipment[eid].ownership = Equipment.Ownership.LEASED
	s.companies[1].money = -500
	s.companies[1].reputation = 10
	var ctx := _tick()
	assert_eq(s.equipment.size(), 1)
	assert_eq(_count(ctx, &"repossessed"), 0)
	assert_eq(s.companies[1].reputation, 5)


func test_seizure_after_three_misses() -> void:
	var id: int = _shark({"balance": 20000, "principal": 20000, "missed_payments": 3})
	s.companies[1].money = 10000
	_tick()
	# interest 1600, due 1642: money 10000-30-1642 = 8328; seize 20% = 1665
	assert_eq(s.companies[1].money, 8328 - 1665)
	assert_eq(s.loans[id].balance, 21600 - 1642 - 1665)
	assert_eq(s.loans[id].missed_payments, 3)


func test_seizure_clears_small_loan() -> void:
	var id: int = _shark({"missed_payments": 3})
	s.companies[1].money = 10000
	_tick()
	assert_false(s.loans.has(id))
	assert_eq(s.companies[1].money, 10000 - 30 - 122 - 958)


func test_months_negative_resets() -> void:
	s.companies[1].money = -100
	_tick()
	assert_eq(s.companies[1].months_negative, 1)
	s.week = 8
	s.companies[1].money = 50
	_tick()
	assert_eq(s.companies[1].months_negative, 0)


func test_bankruptcy_with_no_credit() -> void:
	s.companies[1].money = -50000
	s.companies[1].months_negative = 2
	_shark({"balance": 15000, "principal": 15000})
	s.companies[1].last_missed_week = 0
	s.week = 8
	_tick()
	assert_false(s.game_over)
	s.week = 13
	s.companies[1].months_negative = 2
	var ctx := _tick()
	assert_true(s.game_over)
	assert_eq(_count(ctx, &"game_over"), 1)


func test_shark_credit_prevents_game_over() -> void:
	s.companies[1].money = -5000
	s.companies[1].last_missed_week = 20
	s.week = 26
	s.companies[1].months_negative = 5
	_tick()
	assert_false(s.game_over)


func test_game_over_stops_session() -> void:
	s.game_over = true
	var g := GameSession.new(s, Fixtures.tuning())
	g.set_speed(1)
	g.step_once()
	assert_eq(s.week, 4)
	var r: CommandResult = g.submit(BuyDevKitCommand.new(1, &"platform_fx_micro"))
	assert_false(r.ok)
	assert_eq(r.reason_key, &"error.game_over")
	var back: GameState = GameState.from_dict(Fixtures.json_round_trip(s.to_dict()))
	assert_true(back.game_over)
