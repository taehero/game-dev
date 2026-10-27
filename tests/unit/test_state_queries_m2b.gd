extends GutTest

var _t: TuningDef


func before_each() -> void:
	ContentDB.use(Fixtures.content())
	_t = Fixtures.tuning()


func test_market_salary_view() -> void:
	var s: GameState = Fixtures.new_state(1)
	var id: int = Fixtures.add_staff(s, {"skills": {&"audio": 20, &"art": 20, &"design": 20, &"tech": 20}})
	assert_eq(StateQueries.market_salary(s, id, _t), 680)
	assert_eq(StateQueries.market_salary(s, 999, _t), 0)


func test_monthly_costs_view() -> void:
	var s: GameState = Fixtures.new_state(1)
	Fixtures.add_staff(s, {"salary": 500})
	assert_eq(StateQueries.monthly_costs(s)["total"], 530)


func test_available_credit_view() -> void:
	var s: GameState = Fixtures.new_state(1)
	var bank: int = Fixtures.company_of_kind(s, Company.Kind.BANK)
	assert_eq(StateQueries.available_credit(s, bank, _t), MoneyRules.available_credit(s, s.player_company_id, bank, _t))


func test_pending_ask_view() -> void:
	var s: GameState = Fixtures.new_state(1)
	var id: int = Fixtures.add_staff(s, {})
	assert_eq(StateQueries.pending_ask(s, id), {})
	s.staff[id].asking_raise = 900
	var d := Decision.new()
	d.id = 1
	d.kind = &"promotion_request"
	d.related_ids = [id]
	d.deadline_week = 40
	s.pending_decisions.append(d)
	assert_eq(StateQueries.pending_ask(s, id), {"amount": 900, "promotion": true, "deadline_week": 40})
