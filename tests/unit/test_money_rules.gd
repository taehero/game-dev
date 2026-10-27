extends GutTest


func test_monthly_costs_garage() -> void:
	var s: GameState = Fixtures.new_state(1)
	Fixtures.add_staff(s, {"salary": 500})
	var c: Dictionary = MoneyRules.monthly_costs(s, ContentDB.active(), s.player_company_id)
	assert_eq(c["salaries"], 500)
	assert_eq(c["rent"], 0)
	assert_eq(c["electricity"], 30)
	assert_eq(c["leases"], 0)
	assert_eq(c["total"], 530)


func test_monthly_costs_small_office_and_lease() -> void:
	var s: GameState = Fixtures.new_state(1)
	s.companies[s.player_company_id].office_id = &"office_small"
	Fixtures.add_equipment(s, {"ownership": Equipment.Ownership.LEASED, "seat_index": 1})
	var c: Dictionary = MoneyRules.monthly_costs(s, ContentDB.active(), s.player_company_id)
	assert_eq(c["rent"], 400)
	assert_eq(c["electricity"], 60)
	assert_eq(c["leases"], 60)


func test_storage_equipment_draws_no_power() -> void:
	var s: GameState = Fixtures.new_state(1)
	var before: int = MoneyRules.monthly_costs(s, ContentDB.active(), s.player_company_id)["electricity"]
	Fixtures.add_equipment(s, {"seat_index": -1})
	assert_eq(MoneyRules.monthly_costs(s, ContentDB.active(), s.player_company_id)["electricity"], before)


func test_leased_equipment_no_charge_without_office() -> void:
	var s: GameState = Fixtures.new_state(1)
	Fixtures.add_equipment(s, {"ownership": Equipment.Ownership.LEASED, "seat_index": 1})
	s.companies[s.player_company_id].office_id = &"office_unknown"
	assert_eq(MoneyRules.monthly_costs(s, ContentDB.active(), s.player_company_id)["leases"], 0)


func _bank(s: GameState) -> int:
	return Fixtures.company_of_kind(s, Company.Kind.BANK)


func _shark(s: GameState) -> int:
	return Fixtures.company_of_kind(s, Company.Kind.LENDER)


func test_credit_limits() -> void:
	var s: GameState = Fixtures.new_state(1)
	var t: TuningDef = Fixtures.tuning()
	var p: int = s.player_company_id
	s.companies[p].reputation = 0
	assert_eq(MoneyRules.credit_limit(s, p, _bank(s), t), 10000)
	s.companies[p].reputation = 10
	assert_eq(MoneyRules.credit_limit(s, p, _bank(s), t), 15000)
	assert_eq(MoneyRules.credit_limit(s, p, _shark(s), t), 15000)
	s.companies[p].reputation = 0
	Fixtures.add_loan(s, {"balance": 4000})
	assert_eq(MoneyRules.available_credit(s, p, _bank(s), t), 6000)
	assert_true(MoneyRules.has_credit(s, p, t))


func test_bank_refuses_after_recent_miss() -> void:
	var s: GameState = Fixtures.new_state(1)
	var t: TuningDef = Fixtures.tuning()
	s.week = 60
	s.companies[s.player_company_id].last_missed_week = 50
	assert_true(MoneyRules.bank_refuses(s, s.player_company_id, t))
	assert_eq(MoneyRules.credit_limit(s, s.player_company_id, _bank(s), t), 0)
	s.companies[s.player_company_id].last_missed_week = 8
	assert_false(MoneyRules.bank_refuses(s, s.player_company_id, t))


func test_accountant_lowers_rate() -> void:
	var s: GameState = Fixtures.new_state(1)
	s.owner.perks[&"perk_accountant"] = 1
	s.owner.focus_dev_bp = 0
	assert_eq(MoneyRules.loan_rate_bp(s, ContentDB.active(), _bank(s), Fixtures.tuning()), 85)
	var shark: int = Fixtures.company_of_kind(s, Company.Kind.LENDER)
	assert_eq(MoneyRules.loan_rate_bp(s, ContentDB.active(), shark, Fixtures.tuning()), 680)
