extends GutTest

var s: GameState
var t: TuningDef


func before_each() -> void:
	s = Fixtures.new_state(1)
	t = Fixtures.tuning()
	s.market.platform_install_base[&"platform_fx_micro"] = 70000


func _released(overrides: Dictionary = {}) -> int:
	var o: Dictionary = {"phase": Project.Phase.RELEASED, "user_score": 60, "hype": 0}
	o.merge(overrides, true)
	return Fixtures.add_project(s, o)


func _tick() -> TickContext:
	var ctx := TickContext.new(s, t)
	SalesSystem.tick(ctx)
	return ctx


func test_base_units_set_at_launch() -> void:
	var pid: int = _released()
	_tick()
	assert_eq(s.projects[pid].weekly_units, [1050] as Array[int])
	assert_eq(s.projects[pid].sales_base_units, 1050)


func test_promo_boost_does_not_enter_tail() -> void:
	var pid: int = _released()
	_tick()
	var p: Project = s.projects[pid]
	p.promo_discount_bp = 2000
	p.promo_until_week = 0
	_tick()
	assert_eq(p.weekly_units[1], Fixed.mul_bp(903, 16000))
	assert_eq(p.sales_base_units, 903)
	s.week = 1
	_tick()
	assert_eq(p.weekly_units[2], Fixed.mul_bp(903, 8600))


func test_promo_price_discounted() -> void:
	var pid: int = _released()
	_tick()
	var p: Project = s.projects[pid]
	p.promo_discount_bp = 2000
	p.promo_until_week = 0
	var before: int = p.revenue
	_tick()
	assert_eq(p.revenue - before, 1444 * Fixed.mul_bp(12, 8000))


func test_launch_hype_reduced_by_fatigue() -> void:
	var pid: int = _released({"hype": 50})
	s.companies[1].promo_fatigue = 30
	_tick()
	assert_eq(s.projects[pid].weekly_units[0], Fixed.mul_bp(1050, 12000))


func test_sentiment_moves_decay() -> void:
	var p: Project = s.projects[_released()]
	p.sentiment = -100
	assert_eq(SalesSystem.decay_bp(Fixtures.content(), t, p, 0), 8100)
	p.sentiment = 40
	assert_eq(SalesSystem.decay_bp(Fixtures.content(), t, p, 0), 8800)


func test_mod_tools_improve_decay() -> void:
	var p: Project = s.projects[_released()]
	p.mod_tools = true
	assert_eq(SalesSystem.decay_bp(Fixtures.content(), t, p, 0), 8900)


func test_decay_clamped_at_max() -> void:
	var p: Project = s.projects[_released({"user_score": 100})]
	p.mod_tools = true
	p.sentiment = 100
	assert_eq(SalesSystem.decay_bp(Fixtures.content(), t, p, 0), 9800)


func test_decay_clamp_applies_before_retired_doubling() -> void:
	var p: Project = s.projects[_released({"user_score": 100})]
	p.mod_tools = true
	p.sentiment = 100
	# 9400 + 300 + 500 clamps to 9800, then 2 * 9800 - 10000 = 9600 (swapped order would give 9800)
	assert_eq(SalesSystem.decay_bp(Fixtures.content(), t, p, 400), 9600)


func test_floor_uses_base_units() -> void:
	var pid: int = _released()
	_tick()
	var p: Project = s.projects[pid]
	p.weekly_units[0] = 11
	p.sales_base_units = 11
	p.promo_discount_bp = 5000
	p.promo_until_week = 5
	_tick()
	assert_eq(p.phase, Project.Phase.RETIRED)


func test_book_sale_applies_share_and_royalty() -> void:
	var c := Contract.new()
	c.id = s.alloc_id()
	c.party_a = 1
	c.party_b = 8
	c.revenue_share_pct = 30
	s.contracts[c.id] = c
	var pid: int = _released({"contract_id": c.id})
	var p: Project = s.projects[pid]
	p.config[&"engine"] = &"lic_engine_fx_pro"
	var net: int = SalesSystem.book_sale(TickContext.new(s, t), p, 100, 12)
	assert_eq(net, 720)
	assert_eq(s.companies[8].money, 360)
