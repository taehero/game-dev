extends GutTest

var s: GameState
var t: TuningDef


func before_each() -> void:
	s = Fixtures.new_state(1)
	t = Fixtures.tuning()
	s.market.platform_install_base[&"platform_fx_micro"] = 70000
	s.week = 5


func _live(o: Dictionary = {}) -> int:
	var d: Dictionary = {"phase": Project.Phase.LIVE, "user_score": 60, "hype": 0}
	d.merge(o, true)
	return Fixtures.add_project(s, d)


func _go(pid: int, disc: int, weeks: int) -> TickContext:
	var cmd := StartPromotionCommand.new(pid, disc, weeks)
	var ctx := TickContext.new(s, t)
	cmd.apply(ctx)
	return ctx


func _err(pid: int, disc: int, weeks: int) -> StringName:
	var r := StartPromotionCommand.new(pid, disc, weeks).validate(s, t)
	return &"" if r.ok else r.reason_key


func test_start_sets_window() -> void:
	var pid: int = _live()
	var ctx := _go(pid, 2000, 2)
	assert_eq(s.projects[pid].promo_until_week, 7)
	assert_eq(s.projects[pid].promo_discount_bp, 2000)
	assert_eq(ctx.events[0]["name"], &"promotion_started")
	assert_eq(ctx.events[0]["payload"], {"project_id": pid, "discount_bp": 2000, "until_week": 7})


func test_exactly_n_discounted_sales_weeks() -> void:
	var pid: int = _live({"sales_base_units": 1000})
	var p: Project = s.projects[pid]
	_go(pid, 2000, 2)
	for w in range(6, 9):
		s.week = w
		SalesSystem.tick(TickContext.new(s, t))
	assert_eq(p.weekly_units.size(), 3)
	assert_gt(p.weekly_units[1], p.weekly_units[2] * 12 / 10)
	assert_gt(p.weekly_units[0], p.weekly_units[2] * 12 / 10)


func test_first_promotion_no_fatigue() -> void:
	_go(_live(), 1000, 1)
	assert_eq(s.companies[1].promo_fatigue, 0)


func test_promotion_within_window_adds_fatigue() -> void:
	var other: int = _live({"promo_until_week": 0})
	var pid: int = _live()
	s.week = 10
	_go(pid, 1000, 1)
	assert_eq(s.companies[1].promo_fatigue, 5)
	s.companies[1].promo_fatigue = 0
	s.week = 26  # latest end is 11 (the promo just started), 15 weeks ago
	_go(pid, 1000, 1)
	assert_eq(s.companies[1].promo_fatigue, 5)
	s.companies[1].promo_fatigue = 0
	s.projects[pid].promo_until_week = -1
	s.week = 25  # other ended at 0: 25 < window of 26
	_go(pid, 1000, 1)
	assert_eq(s.companies[1].promo_fatigue, 5)
	s.companies[1].promo_fatigue = 0
	s.projects[pid].promo_until_week = -1
	s.week = 26
	_go(pid, 1000, 1)
	assert_eq(s.companies[1].promo_fatigue, 0)
	assert_true(s.projects.has(other))


func test_rejects_not_live() -> void:
	var pid: int = _live({"phase": Project.Phase.POLISH})
	assert_eq(_err(pid, 1000, 1), &"error.project_not_live")
	assert_eq(_err(999, 1000, 1), &"error.project_not_found")


func test_rejects_running_promo() -> void:
	var pid: int = _live({"promo_discount_bp": 1000, "promo_until_week": 6})
	assert_eq(_err(pid, 1000, 1), &"error.promo_active")
	s.projects[pid].promo_until_week = 5
	assert_eq(_err(pid, 1000, 1), &"")


func test_rejects_bad_discount() -> void:
	var pid: int = _live()
	for d in [0, 1500, 6000]:
		assert_eq(_err(pid, d, 1), &"error.invalid_discount")
	assert_eq(_err(pid, 5000, 1), &"")


func test_rejects_bad_weeks() -> void:
	var pid: int = _live()
	assert_eq(_err(pid, 1000, 0), &"error.invalid_promo_weeks")
	assert_eq(_err(pid, 1000, 5), &"error.invalid_promo_weeks")
