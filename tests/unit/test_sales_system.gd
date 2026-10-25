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


func test_launch_week_units_and_revenue() -> void:
	var pid: int = _released()
	var ctx: TickContext = _tick()
	# 70000 * 1.5 * 0.01 * 1.0 (hype 0) * 1.0 (score 60 -> 10000) = 1050
	assert_eq(s.projects[pid].weekly_units, [1050] as Array[int])
	assert_eq(s.projects[pid].phase, Project.Phase.LIVE)
	assert_eq(s.projects[pid].revenue, 12600)
	assert_eq(s.companies[1].money, 20000 + 12600)
	var names: Array[StringName] = []
	for e: Dictionary in ctx.events:
		names.append(e["name"])
	assert_true(names.has(&"sales_updated"))
	assert_true(names.has(&"project_phase_changed"))
	assert_true(names.has(&"money_changed"))


func test_weekly_decay_from_review_table() -> void:
	var pid: int = _released()
	_tick()
	_tick()
	assert_eq(s.projects[pid].weekly_units[1], Fixed.mul_bp(1050, 8600))


func test_retired_platform_doubles_decay() -> void:
	var pid: int = _released()
	_tick()
	s.week = 400
	_tick()
	assert_eq(s.projects[pid].weekly_units[1], Fixed.mul_bp(1050, 7200))


func test_below_floor_retires() -> void:
	var pid: int = _released({"user_score": 10})
	s.market.platform_install_base[&"platform_fx_micro"] = 100
	_tick()
	assert_eq(s.projects[pid].phase, Project.Phase.RETIRED)
	assert_eq(s.projects[pid].weekly_units.size(), 0)


func test_history_capped_at_104() -> void:
	var pid: int = _released({"user_score": 100})
	s.market.platform_install_base[&"platform_fx_micro"] = 10000000
	for i: int in 110:
		_tick()
	assert_eq(s.projects[pid].weekly_units.size(), 104)


func test_publisher_share_and_royalty() -> void:
	var c := Contract.new()
	c.id = s.alloc_id()
	c.party_a = 1
	c.party_b = 8
	c.revenue_share_pct = 30
	s.contracts[c.id] = c
	var pid: int = _released({"contract_id": c.id})
	s.projects[pid].config[&"engine"] = &"lic_engine_fx_pro"  # royalty 1000bp
	_tick()
	# gross 12600; publisher 3780; royalty 1260; net 7560
	assert_eq(s.projects[pid].revenue, 7560)
	assert_eq(s.companies[8].money, 3780)


func test_table_bp_clamps_both_ends() -> void:
	var table: Array[int] = [1, 2, 3]
	assert_eq(SalesSystem.table_bp(table, -50), 1)
	assert_eq(SalesSystem.table_bp(table, 10), 2)
	assert_eq(SalesSystem.table_bp(table, 500), 3)


func test_royalty_bp_prefers_contract_and_zero_for_built() -> void:
	var pid: int = _released()
	var p: Project = s.projects[pid]
	assert_eq(SalesSystem.royalty_bp(s, Fixtures.content(), p), 0, "homebrew def royalty 0")
	p.config[&"engine"] = &"lic_engine_fx_pro"
	assert_eq(SalesSystem.royalty_bp(s, Fixtures.content(), p), 1000)
	var c := Contract.new()
	c.id = s.alloc_id()
	c.kind = Contract.Kind.ENGINE_LICENSE
	c.party_a = p.company_id
	c.deliverable = &"lic_engine_fx_pro"
	c.royalty_bp = 400
	s.contracts[c.id] = c
	assert_eq(SalesSystem.royalty_bp(s, Fixtures.content(), p), 400)
	var eid: int = Fixtures.add_engine(s)
	p.engine_id = eid
	assert_eq(SalesSystem.royalty_bp(s, Fixtures.content(), p), 0)


func test_missing_install_base_entry_gives_zero_units_and_retires() -> void:
	var pid: int = _released()
	s.market.platform_install_base.erase(&"platform_fx_micro")
	_tick()
	assert_eq(s.projects[pid].phase, Project.Phase.RETIRED)
