extends GutTest

var s: GameState
var t: TuningDef


func before_each() -> void:
	s = Fixtures.new_state(1)
	t = Fixtures.tuning()


func _run(cmd: Command) -> TickContext:
	var ctx := TickContext.new(s, t)
	cmd.apply(ctx)
	return ctx


func _bank() -> int:
	return Fixtures.company_of_kind(s, Company.Kind.BANK)


func test_take_bank_loan() -> void:
	var cmd := TakeLoanCommand.new(1, _bank(), 5000)
	assert_true(cmd.validate(s, t).ok)
	var ctx := _run(cmd)
	assert_eq(s.companies[1].money, 25000)
	var l: Loan = s.loans[s.sorted_ids(s.loans)[0]]
	assert_eq(l.balance, 5000)
	assert_eq(l.rate_bp_per_month, 100)
	assert_eq(l.payment_per_month, 209)
	assert_eq(ctx.events[0]["name"], &"loan_taken")


func test_take_loan_rejections() -> void:
	assert_eq(TakeLoanCommand.new(1, 1, 100).validate(s, t).reason_key, &"error.lender_not_found")
	assert_eq(TakeLoanCommand.new(1, _bank(), 0).validate(s, t).reason_key, &"error.invalid_amount")
	assert_eq(TakeLoanCommand.new(1, _bank(), 10001).validate(s, t).reason_key, &"error.over_credit_limit")
	s.week = 10
	s.companies[1].last_missed_week = 5
	assert_eq(TakeLoanCommand.new(1, _bank(), 100).validate(s, t).reason_key, &"error.bank_refused")
	var shark: int = Fixtures.company_of_kind(s, Company.Kind.LENDER)
	assert_true(TakeLoanCommand.new(1, shark, 100).validate(s, t).ok)


func test_repay() -> void:
	var id: int = Fixtures.add_loan(s)
	assert_true(RepayLoanCommand.new(id, 1000).validate(s, t).ok)
	_run(RepayLoanCommand.new(id, 1000))
	assert_eq(s.loans[id].balance, 4000)
	assert_eq(s.companies[1].money, 19000)
	assert_eq(RepayLoanCommand.new(id, 0).validate(s, t).reason_key, &"error.invalid_amount")
	assert_eq(RepayLoanCommand.new(id, 4001).validate(s, t).reason_key, &"error.invalid_amount")
	assert_eq(RepayLoanCommand.new(999, 1).validate(s, t).reason_key, &"error.loan_not_found")
	_run(RepayLoanCommand.new(id, 4000))
	assert_false(s.loans.has(id))
