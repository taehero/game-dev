extends GutTest

var _t: TuningDef


func before_each() -> void:
	_t = Fixtures.tuning()


func _run(s: GameState, pid: int, ch: StringName) -> CommandResult:
	var cmd := RunMarketingCommand.new(pid, ch)
	var r := cmd.validate(s, _t)
	if r.ok:
		cmd.apply(TickContext.new(s, _t))
	return r


func test_run_marketing_charges_and_adds_hype() -> void:
	var s := Fixtures.new_state(1)
	var pid := Fixtures.add_project(s, {"hype": 10})
	var ctx := TickContext.new(s, _t)
	var cmd := RunMarketingCommand.new(pid, &"channel_fx_ad")
	assert_true(cmd.validate(s, _t).ok)
	cmd.apply(ctx)
	assert_eq(s.projects[pid].hype, 30)
	assert_eq(s.companies[1].money, 19500)
	assert_eq(ctx.events[0]["name"], &"money_changed")
	assert_eq(ctx.events[1]["name"], &"project_changed")


func test_hype_caps_at_100() -> void:
	var s := Fixtures.new_state(1)
	var pid := Fixtures.add_project(s, {"hype": 95})
	_run(s, pid, &"channel_fx_ad")
	assert_eq(s.projects[pid].hype, 100)


func test_polish_project_can_market() -> void:
	var s := Fixtures.new_state(1)
	var pid := Fixtures.add_project(s, {"phase": Project.Phase.POLISH})
	assert_true(_run(s, pid, &"channel_fx_ad").ok)


func test_released_project_rejected() -> void:
	var s := Fixtures.new_state(1)
	var pid := Fixtures.add_project(s, {"phase": Project.Phase.RELEASED})
	assert_eq(_run(s, pid, &"channel_fx_ad").reason_key, &"error.project_not_marketable")
	assert_eq(_run(s, 999, &"channel_fx_ad").reason_key, &"error.project_not_found")


func test_unknown_channel_rejected() -> void:
	var s := Fixtures.new_state(1)
	var pid := Fixtures.add_project(s)
	assert_eq(_run(s, pid, &"channel_nope").reason_key, &"error.channel_not_found")


func test_locked_channel_rejected() -> void:
	var s := Fixtures.new_state(1)
	var pid := Fixtures.add_project(s)
	assert_eq(_run(s, pid, &"channel_fx_tv").reason_key, &"error.item_locked")
	s.companies[1].unlocked.append(&"research_fx_tv")
	assert_true(_run(s, pid, &"channel_fx_tv").ok)


func test_out_of_era_channel_rejected() -> void:
	var s := Fixtures.new_state(1)
	var pid := Fixtures.add_project(s)
	assert_eq(_run(s, pid, &"channel_fx_old").reason_key, &"error.channel_unavailable")


func test_trade_show_only_on_its_weeks() -> void:
	var s := Fixtures.new_state(1)
	var pid := Fixtures.add_project(s)
	s.week = 9
	assert_eq(_run(s, pid, &"channel_fx_show").reason_key, &"error.channel_unavailable")
	s.week = 10
	assert_true(_run(s, pid, &"channel_fx_show").ok)


func test_not_enough_money_rejected() -> void:
	var s := Fixtures.new_state(1)
	var pid := Fixtures.add_project(s)
	s.companies[1].money = 499
	assert_eq(_run(s, pid, &"channel_fx_ad").reason_key, &"error.not_enough_money")
	s.companies[1].money = 500
	assert_true(_run(s, pid, &"channel_fx_ad").ok)
	assert_eq(s.companies[1].money, 0)


func test_tick_decays_hype_in_development_only() -> void:
	var s := Fixtures.new_state(1)
	var a := Fixtures.add_project(s, {"hype": 50})
	var b := Fixtures.add_project(s, {"hype": 50, "phase": Project.Phase.RELEASED})
	MarketingSystem.tick(TickContext.new(s, _t))
	assert_eq(s.projects[a].hype, 47)
	assert_eq(s.projects[b].hype, 50)


func test_month_start_recovers_fatigue() -> void:
	var s := Fixtures.new_state(1)
	s.companies[1].promo_fatigue = 3
	s.week = 0
	MarketingSystem.tick(TickContext.new(s, _t))
	assert_eq(s.companies[1].promo_fatigue, 2)
	s.week = 1
	MarketingSystem.tick(TickContext.new(s, _t))
	assert_eq(s.companies[1].promo_fatigue, 2)
	s.companies[1].promo_fatigue = 0
	s.week = 0
	MarketingSystem.tick(TickContext.new(s, _t))
	assert_eq(s.companies[1].promo_fatigue, 0)


func test_last_promo_end() -> void:
	var s := Fixtures.new_state(1)
	assert_eq(MarketingSystem.last_promo_end(s, 1), -1)
	Fixtures.add_project(s, {"promo_until_week": 7})
	Fixtures.add_project(s, {"promo_until_week": 12})
	assert_eq(MarketingSystem.last_promo_end(s, 1), 12)


func test_promoter_perk_boosts_hype() -> void:
	var perk := PerkDef.new()
	perk.id = &"perk_fx_promoter"
	perk.path = &"BUSINESS"
	perk.max_rank = 3
	perk.effects_bp_per_rank[&"hype_gain_bp"] = 1000
	var db := Fixtures.content_plus([perk, Fixtures.content().channels[&"channel_fx_ad"]] as Array[Resource])
	var s := Fixtures.new_state(1)
	ContentDB.use(db)
	s.owner.perks[&"perk_fx_promoter"] = 1
	s.owner.focus_dev_bp = 0
	var pid := Fixtures.add_project(s, {"hype": 10})
	_run(s, pid, &"channel_fx_ad")
	assert_eq(s.projects[pid].hype, 32)  # 20 * 1.1 = 22
	ContentDB.use(Fixtures.content())
