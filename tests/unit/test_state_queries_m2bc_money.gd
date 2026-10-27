extends GutTest

var _t: TuningDef


func before_each() -> void:
	ContentDB.use(Fixtures.content())
	_t = Fixtures.tuning()


func test_game_over_view_fresh() -> void:
	var s := Fixtures.new_state(1)
	var v: Dictionary = StateQueries.game_over_view(s, _t)
	assert_eq(v["over"], false)
	assert_eq(v["months_negative"], 0)
	assert_eq(v["money"], 20000)
	assert_eq(v["credit_left"], 25000)
	assert_eq(v["games_released"], 0)


func test_game_over_view_bankrupt() -> void:
	var s := Fixtures.new_state(1)
	var shark: int = Fixtures.company_of_kind(s, Company.Kind.LENDER)
	s.game_over = true
	var company: Company = s.companies[s.player_company_id]
	company.months_negative = 3
	company.money = -500
	company.last_missed_week = s.week
	Fixtures.add_loan(s, {"lender_id": shark, "balance": 15000})
	var v: Dictionary = StateQueries.game_over_view(s, _t)
	assert_eq(v["over"], true)
	assert_eq(v["months_negative"], 3)
	assert_eq(v["money"], -500)
	assert_eq(v["credit_left"], 0)


func test_lender_rows_fresh() -> void:
	var s := Fixtures.new_state(1)
	var c: ContentDB = Fixtures.content()
	var bank: int = Fixtures.company_of_kind(s, Company.Kind.BANK)
	var shark: int = Fixtures.company_of_kind(s, Company.Kind.LENDER)
	var rows: Array[Dictionary] = StateQueries.lender_rows(s, c, _t)
	assert_eq(rows.size(), 2)
	assert_eq(rows[0]["id"], bank)
	assert_eq(rows[0]["is_shark"], false)
	assert_eq(rows[0]["limit"], 10000)
	assert_eq(rows[0]["available"], 10000)
	assert_eq(rows[0]["rate_bp"], 100)
	assert_eq(rows[0]["refuses"], false)
	assert_eq(rows[0]["name"], "company.bank.name")
	assert_eq(rows[1]["id"], shark)
	assert_eq(rows[1]["is_shark"], true)
	assert_eq(rows[1]["limit"], 15000)
	assert_eq(rows[1]["rate_bp"], 800)
	assert_eq(rows[1]["name"], "company.lender.name")


func test_lender_rows_owed_and_refused() -> void:
	var s := Fixtures.new_state(1)
	var c: ContentDB = Fixtures.content()
	Fixtures.add_loan(s, {"balance": 4000})
	var bank: int = Fixtures.company_of_kind(s, Company.Kind.BANK)
	var shark: int = Fixtures.company_of_kind(s, Company.Kind.LENDER)
	var rows: Array[Dictionary] = StateQueries.lender_rows(s, c, _t)
	assert_eq(rows[0]["available"], 6000)
	s.companies[s.player_company_id].last_missed_week = s.week
	rows = StateQueries.lender_rows(s, c, _t)
	assert_eq(rows[0]["refuses"], true)
	assert_eq(rows[0]["limit"], 0)
	assert_eq(rows[0]["available"], 0)
	assert_eq(rows[1]["refuses"], false)
	assert_eq(rows[0]["id"], bank)
	assert_eq(rows[1]["id"], shark)


func test_lender_rate_with_accountant() -> void:
	var s := Fixtures.new_state(1)
	var c: ContentDB = Fixtures.content()
	s.owner.perks[&"perk_accountant"] = 1
	s.owner.focus_dev_bp = 0
	var rows: Array[Dictionary] = StateQueries.lender_rows(s, c, _t)
	assert_eq(rows[0]["rate_bp"], 85)
	assert_eq(rows[1]["rate_bp"], 680)


func test_loan_rows() -> void:
	var s := Fixtures.new_state(1)
	var bank: int = Fixtures.company_of_kind(s, Company.Kind.BANK)
	var shark: int = Fixtures.company_of_kind(s, Company.Kind.LENDER)
	var bank_loan: int = Fixtures.add_loan(s)
	var shark_loan: int = Fixtures.add_loan(s, {"lender_id": shark})
	Fixtures.add_loan(s, {"company_id": bank})
	var rows: Array[Dictionary] = StateQueries.loan_rows(s)
	assert_eq(rows.size(), 2)
	assert_eq(rows[0]["id"], bank_loan)
	assert_eq(rows[0]["lender_id"], bank)
	assert_eq(rows[0]["lender_name"], "company.bank.name")
	assert_eq(rows[0]["is_shark"], false)
	assert_eq(rows[0]["principal"], 5000)
	assert_eq(rows[0]["balance"], 5000)
	assert_eq(rows[0]["rate_bp"], 100)
	assert_eq(rows[0]["payment"], 209)
	assert_eq(rows[0]["missed"], 0)
	assert_eq(rows[0]["taken_week"], s.week)
	assert_eq(rows[1]["id"], shark_loan)
	assert_eq(rows[1]["lender_id"], shark)
	assert_eq(rows[1]["lender_name"], "company.lender.name")
	assert_eq(rows[1]["is_shark"], true)


func test_contract_offers_filters() -> void:
	var s := Fixtures.new_state(1)
	var offer: int = Fixtures.add_contract(s, {"price": 900, "delivery_week": 4, "deadline_week": 10})
	s.contracts[offer].target_points[&"design"] = 100
	s.contracts[offer].target_points[&"tech"] = 50
	s.contracts[offer].target_points[&"art"] = 0
	s.contracts[offer].target_points[&"audio"] = 20
	Fixtures.add_contract(s, {"project_id": 77})
	Fixtures.add_contract(s, {"delivery_week": 0})
	Fixtures.add_contract(s, {"kind": Contract.Kind.OUTSOURCE})
	var rows: Array[Dictionary] = StateQueries.contract_offers(s)
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["pay"], 900)
	assert_eq(rows[0]["expires_week"], 4)
	assert_eq(rows[0]["deadline_week"], 10)
	assert_eq(rows[0]["targets"][&"design"], 100)
	assert_eq(rows[0]["publisher_name"], s.companies[s.contracts[offer].party_b].name)


func test_contract_jobs() -> void:
	var s := Fixtures.new_state(1)
	var cid: int = Fixtures.add_contract(s, {"price": 900, "deadline_week": 10})
	var pid: int = Fixtures.add_project(s, {"kind": Project.Kind.CONTRACT_WORK, "contract_id": cid, "deadline_week": 10})
	s.projects[pid].points[&"design"] = 30
	var rows: Array[Dictionary] = StateQueries.contract_jobs(s)
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["project_id"], pid)
	assert_eq(rows[0]["pay"], 900)
	assert_eq(rows[0]["points"][&"design"], 30)


func test_office_rows_garage() -> void:
	var s := Fixtures.new_state(1)
	var c: ContentDB = Fixtures.content()
	var rows: Array[Dictionary] = StateQueries.office_rows(s, c)
	assert_eq(rows.size(), 2)
	assert_eq(rows[0]["id"], &"office_garage")
	assert_eq(rows[0]["current"], true)
	assert_eq(rows[0]["monthly_total"], 30)
	assert_eq(rows[1]["id"], &"office_small")
	assert_eq(rows[1]["current"], false)
	assert_eq(rows[1]["rent"], 400)
	assert_eq(rows[1]["seats"], 5)
	assert_eq(rows[1]["moving_cost"], 1500)
	assert_eq(rows[1]["monthly_total"], 450)


func test_money_views_are_pure() -> void:
	var s := Fixtures.new_state(1)
	var c: ContentDB = Fixtures.content()
	var before: String = StateHash.of(s)
	StateQueries.game_over_view(s, _t)
	StateQueries.lender_rows(s, c, _t)
	StateQueries.loan_rows(s)
	StateQueries.contract_offers(s)
	StateQueries.contract_jobs(s)
	StateQueries.office_rows(s, c)
	assert_eq(StateHash.of(s), before)
