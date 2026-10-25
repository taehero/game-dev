extends GutTest


func _sample_staff() -> Staff:
	var s := Staff.new()
	s.id = 7
	s.company_id = 2
	s.name = "Ada"
	s.skills = {&"design": 40, &"tech": 80, &"art": 10, &"audio": 5}
	s.traits = [&"perfectionist", &"night_owl"]
	s.morale = 55
	s.burnout = 12
	s.salary = 900
	s.assigned_project_id = 3
	s.role = Staff.Role.LEAD_TECH
	s.exp = {&"art": 12, &"tech": 340}
	s.seat_index = 2
	s.last_raise_week = 40
	s.asking_raise = 150
	s.is_owner = true
	s.level = Staff.Level.SENIOR
	s.title = &"level_senior_dev"
	s.hired_week = 25
	s.week_points = {&"design": 7, &"audio": 3}
	return s


func _sample_company() -> Company:
	var c := Company.new()
	c.id = 4
	c.name = "Pixel Pub"
	c.kind = Company.Kind.AI_PUBLISHER
	c.money = 123456
	c.reputation = 61
	c.fan_count = 9000
	c.kind = Company.Kind.LENDER
	c.office_id = &"office_garage"
	c.research_points = 77
	c.unlocked = [&"topic_space", &"genre_rpg"]
	c.dev_kits = [&"platform_pc"]
	c.months_negative = 3
	c.awards = [&"award_best_indie"]
	return c


func _sample_contract() -> Contract:
	var c := Contract.new()
	c.id = 9
	c.kind = Contract.Kind.PUBLISHING
	c.party_a = 1
	c.party_b = 4
	c.advance = 50000
	c.revenue_share_pct = 30
	c.deadline_week = 120
	c.late_penalty_per_week = 500
	c.locked_genre = &"genre_rpg"
	c.locked_platform = &"platform_pc"
	c.min_score = 70
	c.kind = Contract.Kind.ENGINE_LICENSE
	c.price = 5000
	c.royalty_bp = 750
	c.target_points = {&"art": 300}
	c.quality_roll = 64
	c.delivery_week = 88
	c.project_id = -1
	c.deliverable = &"lic_engine_homebrew"
	return c


func _json(d: Dictionary) -> String:
	return JSON.stringify(d, "", true, true)


func test_staff_survives_json_round_trip() -> void:
	var s := _sample_staff()
	var back: Staff = Staff.from_dict(Fixtures.json_round_trip(s.to_dict()))
	assert_eq(_json(back.to_dict()), _json(s.to_dict()))
	assert_eq(typeof(back.id), TYPE_INT)
	assert_eq(typeof(back.skills.keys()[0]), TYPE_STRING_NAME)
	assert_eq(typeof(back.traits[0]), TYPE_STRING_NAME)
	assert_eq(back.role, Staff.Role.LEAD_TECH)
	assert_eq(back.level, Staff.Level.SENIOR)
	assert_eq(typeof(back.exp.keys()[0]), TYPE_STRING_NAME)
	assert_eq(back.week_points[&"design"], 7)
	assert_true(back.is_owner)
	assert_eq(back.assigned_project_id, 3)


func test_staff_schema_accepts_round_tripped_dict() -> void:
	assert_true(SaveSchema.check(Fixtures.json_round_trip(_sample_staff().to_dict()), Staff.SCHEMA))


func test_staff_enum_serializes_as_name() -> void:
	assert_eq(_sample_staff().to_dict()["role"], "LEAD_TECH")


func test_company_survives_json_round_trip() -> void:
	var c := _sample_company()
	var back: Company = Company.from_dict(Fixtures.json_round_trip(c.to_dict()))
	assert_eq(_json(back.to_dict()), _json(c.to_dict()))
	assert_eq(typeof(back.money), TYPE_INT)
	assert_eq(back.kind, Company.Kind.LENDER)
	assert_eq(typeof(back.office_id), TYPE_STRING_NAME)
	assert_eq(typeof(back.unlocked[0]), TYPE_STRING_NAME)


func test_company_schema_accepts_round_tripped_dict() -> void:
	assert_true(SaveSchema.check(Fixtures.json_round_trip(_sample_company().to_dict()), Company.SCHEMA))


func test_company_enum_serializes_as_name() -> void:
	assert_eq(_sample_company().to_dict()["kind"], "LENDER")


func test_contract_survives_json_round_trip() -> void:
	var c := _sample_contract()
	var back: Contract = Contract.from_dict(Fixtures.json_round_trip(c.to_dict()))
	assert_eq(_json(back.to_dict()), _json(c.to_dict()))
	assert_eq(typeof(back.locked_genre), TYPE_STRING_NAME)
	assert_eq(back.locked_genre, &"genre_rpg")
	assert_eq(back.min_score, 70)
	assert_eq(back.kind, Contract.Kind.ENGINE_LICENSE)
	assert_eq(back.target_points[&"art"], 300)
	assert_eq(typeof(back.deliverable), TYPE_STRING_NAME)


func test_contract_schema_accepts_round_tripped_dict() -> void:
	assert_true(SaveSchema.check(Fixtures.json_round_trip(_sample_contract().to_dict()), Contract.SCHEMA))


func test_contract_enum_serializes_as_name() -> void:
	assert_eq(_sample_contract().to_dict()["kind"], "ENGINE_LICENSE")
