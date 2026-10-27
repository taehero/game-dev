extends GutTest

var _t: TuningDef = Fixtures.tuning()


func after_each() -> void:
	ContentDB.use(Fixtures.content())


func test_player_money_reads_player_company() -> void:
	var s := Fixtures.new_state(1)
	assert_eq(StateQueries.player_money(s), _t.start_money)
	s.companies[s.player_company_id].money = 1234
	assert_eq(StateQueries.player_money(s), 1234)
	s.companies.erase(s.player_company_id)
	assert_eq(StateQueries.player_money(s), 0, "missing player company")


func test_market_salary_unknown_staff_is_zero() -> void:
	var s := Fixtures.new_state(1)
	ContentDB.use(Fixtures.content())
	assert_eq(StateQueries.market_salary(s, 9999, _t), 0)


func test_market_salary_matches_people_rules() -> void:
	var s := Fixtures.new_state(1)
	ContentDB.use(Fixtures.content())
	var sid: int = Fixtures.add_staff(s)
	var st: Staff = s.staff[sid]
	var expected: int = PeopleRules.market_salary(st.skills, int(st.level), Fixtures.content(), _t)
	assert_eq(StateQueries.market_salary(s, sid, _t), expected)
	assert_eq(StateQueries.market_salary(s, sid, _t), 680, "junior: era_wage_base 200 + 80 * 6")
	st.level = Staff.Level.MID
	assert_eq(StateQueries.market_salary(s, sid, _t), 884, "mid salary_bp 13000")


func test_monthly_costs_match_money_rules() -> void:
	var s := Fixtures.new_state(1)
	ContentDB.use(Fixtures.content())
	var c: Dictionary = StateQueries.monthly_costs(s)
	assert_eq(c, MoneyRules.monthly_costs(s, ContentDB.active(), s.player_company_id))
	assert_eq(c["salaries"], 0)
	assert_eq(c["electricity"], 30)
	assert_eq(c["total"], 30)


func test_monthly_costs_salaries_rise_by_added_salary() -> void:
	var s := Fixtures.new_state(1)
	ContentDB.use(Fixtures.content())
	Fixtures.add_staff(s, {"salary": 500})
	var before: Dictionary = StateQueries.monthly_costs(s)
	Fixtures.add_staff(s, {"salary": 700})
	var after: Dictionary = StateQueries.monthly_costs(s)
	assert_eq(int(after["salaries"]), int(before["salaries"]) + 700)
	assert_eq(int(after["total"]), int(before["total"]) + 700)