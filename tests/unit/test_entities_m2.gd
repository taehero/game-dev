extends GutTest


func _json(d: Dictionary) -> String:
	return JSON.stringify(d, "", true, true)


func _owner() -> OwnerProfile:
	var o := OwnerProfile.new()
	o.staff_id = 4
	o.xp = 120
	o.skill_points = 3
	o.perks = {&"perk_coder": 2, &"perk_artist": 1}
	o.focus_dev_bp = 12500
	return o


func _equipment() -> Equipment:
	var e := Equipment.new()
	e.id = 7
	e.company_id = 1
	e.def_id = &"equip_desk"
	e.ownership = Equipment.Ownership.LEASED
	e.seat_index = 2
	e.bought_week = 30
	e.value = 900
	return e


func _engine() -> GameEngine:
	var g := GameEngine.new()
	g.id = 3
	g.company_id = 1
	g.name = "Spark"
	g.features = [&"feat_2d", &"feat_audio"]
	g.tech_cap = 40
	g.source = GameEngine.Source.OUTSOURCED
	g.built_week = 55
	return g


func _loan() -> Loan:
	var l := Loan.new()
	l.id = 2
	l.company_id = 1
	l.lender_id = 6
	l.principal = 50000
	l.balance = 42000
	l.rate_bp_per_month = 150
	l.payment_per_month = 3000
	l.missed_payments = 1
	l.taken_week = 12
	return l


func _candidate() -> Candidate:
	var c := Candidate.new()
	c.id = 9
	c.name = "Ada"
	c.skills = {&"design": 12, &"tech": 30}
	c.traits = [&"trait_fast", &"trait_shy"]
	c.asking_salary = 1800
	c.expires_week = 77
	c.level = 2
	return c


func _review() -> ReviewResult:
	var r := ReviewResult.new()
	r.outlet_id = &"outlet_gamezine"
	r.score_x10 = 77
	r.strength_key = &"review.strength.gameplay"
	r.weakness_key = &"review.weakness.bugs"
	return r


func test_owner_round_trip() -> void:
	var o := _owner()
	var back: OwnerProfile = OwnerProfile.from_dict(Fixtures.json_round_trip(o.to_dict()))
	assert_eq(_json(back.to_dict()), _json(o.to_dict()))
	assert_eq(typeof(back.xp), TYPE_INT)
	assert_eq(typeof(back.perks.keys()[0]), TYPE_STRING_NAME)


func test_owner_schema() -> void:
	assert_true(SaveSchema.check(Fixtures.json_round_trip(_owner().to_dict()), OwnerProfile.SCHEMA))


func test_owner_perks_keep_int_ranks() -> void:
	var o := OwnerProfile.new()
	o.perks = {&"perk_coder": 2}
	var back := OwnerProfile.from_dict(Fixtures.json_round_trip(o.to_dict()))
	assert_eq(typeof(back.perks[&"perk_coder"]), TYPE_INT)
	assert_eq(back.perks[&"perk_coder"], 2)


func test_equipment_round_trip() -> void:
	var e := _equipment()
	var back: Equipment = Equipment.from_dict(Fixtures.json_round_trip(e.to_dict()))
	assert_eq(_json(back.to_dict()), _json(e.to_dict()))
	assert_eq(typeof(back.value), TYPE_INT)
	assert_eq(typeof(back.def_id), TYPE_STRING_NAME)
	assert_eq(back.ownership, Equipment.Ownership.LEASED)


func test_equipment_schema() -> void:
	assert_true(SaveSchema.check(Fixtures.json_round_trip(_equipment().to_dict()), Equipment.SCHEMA))


func test_equipment_enum_serializes_as_name() -> void:
	assert_eq(_equipment().to_dict()["ownership"], "LEASED")


func test_engine_round_trip() -> void:
	var g := _engine()
	var back: GameEngine = GameEngine.from_dict(Fixtures.json_round_trip(g.to_dict()))
	assert_eq(_json(back.to_dict()), _json(g.to_dict()))
	assert_eq(typeof(back.tech_cap), TYPE_INT)
	assert_eq(typeof(back.features[0]), TYPE_STRING_NAME)
	assert_eq(back.source, GameEngine.Source.OUTSOURCED)


func test_engine_schema() -> void:
	assert_true(SaveSchema.check(Fixtures.json_round_trip(_engine().to_dict()), GameEngine.SCHEMA))


func test_engine_enum_serializes_as_name() -> void:
	assert_eq(_engine().to_dict()["source"], "OUTSOURCED")


func test_loan_round_trip() -> void:
	var l := _loan()
	var back: Loan = Loan.from_dict(Fixtures.json_round_trip(l.to_dict()))
	assert_eq(_json(back.to_dict()), _json(l.to_dict()))
	assert_eq(typeof(back.balance), TYPE_INT)
	assert_eq(back.missed_payments, 1)


func test_loan_schema() -> void:
	assert_true(SaveSchema.check(Fixtures.json_round_trip(_loan().to_dict()), Loan.SCHEMA))


func test_candidate_round_trip() -> void:
	var c := _candidate()
	var back: Candidate = Candidate.from_dict(Fixtures.json_round_trip(c.to_dict()))
	assert_eq(_json(back.to_dict()), _json(c.to_dict()))
	assert_eq(typeof(back.level), TYPE_INT)
	assert_eq(typeof(back.skills.keys()[0]), TYPE_STRING_NAME)
	assert_eq(typeof(back.traits[0]), TYPE_STRING_NAME)


func test_candidate_schema() -> void:
	assert_true(SaveSchema.check(Fixtures.json_round_trip(_candidate().to_dict()), Candidate.SCHEMA))


func test_review_round_trip() -> void:
	var r := _review()
	var back: ReviewResult = ReviewResult.from_dict(Fixtures.json_round_trip(r.to_dict()))
	assert_eq(_json(back.to_dict()), _json(r.to_dict()))
	assert_eq(typeof(back.score_x10), TYPE_INT)
	assert_eq(typeof(back.outlet_id), TYPE_STRING_NAME)


func test_review_schema() -> void:
	assert_true(SaveSchema.check(Fixtures.json_round_trip(_review().to_dict()), ReviewResult.SCHEMA))
