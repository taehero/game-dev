extends GutTest

var _t: TuningDef


func before_each() -> void:
	ContentDB.use(Fixtures.content())
	_t = Fixtures.tuning()


func test_shark_lender_has_full_credit() -> void:
	var s: GameState = Fixtures.new_state(1)
	var shark: int = Fixtures.company_of_kind(s, Company.Kind.LENDER)
	assert_eq(StateQueries.available_credit(s, shark, _t), _t.shark_limit)


func test_bank_loan_reduces_credit_by_its_balance() -> void:
	var s: GameState = Fixtures.new_state(1)
	var bank: int = Fixtures.company_of_kind(s, Company.Kind.BANK)
	var base: int = StateQueries.available_credit(s, bank, _t)
	Fixtures.add_loan(s, {"balance": 3000})
	assert_eq(StateQueries.available_credit(s, bank, _t), base - 3000)


func test_other_lender_loan_does_not_reduce_bank_credit() -> void:
	var s: GameState = Fixtures.new_state(1)
	var bank: int = Fixtures.company_of_kind(s, Company.Kind.BANK)
	var shark: int = Fixtures.company_of_kind(s, Company.Kind.LENDER)
	var bank_base: int = StateQueries.available_credit(s, bank, _t)
	var shark_base: int = StateQueries.available_credit(s, shark, _t)
	Fixtures.add_loan(s, {"lender_id": shark, "balance": 4000})
	assert_eq(StateQueries.available_credit(s, bank, _t), bank_base)
	assert_eq(StateQueries.available_credit(s, shark, _t), shark_base - 4000)


func test_credit_never_goes_negative() -> void:
	var s: GameState = Fixtures.new_state(1)
	var bank: int = Fixtures.company_of_kind(s, Company.Kind.BANK)
	Fixtures.add_loan(s, {"balance": 999999})
	assert_eq(StateQueries.available_credit(s, bank, _t), 0)


func test_bank_refusal_after_missed_payment_expires() -> void:
	var s: GameState = Fixtures.new_state(1)
	var bank: int = Fixtures.company_of_kind(s, Company.Kind.BANK)
	var shark: int = Fixtures.company_of_kind(s, Company.Kind.LENDER)
	var base: int = StateQueries.available_credit(s, bank, _t)
	s.companies[s.player_company_id].last_missed_week = s.week
	assert_eq(StateQueries.available_credit(s, bank, _t), 0)
	assert_eq(StateQueries.available_credit(s, shark, _t), _t.shark_limit)
	s.week += _t.bank_refuse_weeks
	assert_eq(StateQueries.available_credit(s, bank, _t), base)


func test_unknown_lender_has_no_credit() -> void:
	var s: GameState = Fixtures.new_state(1)
	assert_eq(StateQueries.available_credit(s, 9999, _t), 0)
