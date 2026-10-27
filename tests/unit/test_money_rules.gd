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
