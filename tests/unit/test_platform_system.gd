extends GutTest


func test_install_base_interpolates_and_holds_last_value() -> void:
	var p: PlatformDef = Fixtures.content().platforms[&"platform_fx_console"]
	assert_eq(PlatformSystem.install_base(p, 19), 0)
	assert_eq(PlatformSystem.install_base(p, 20), 0)
	assert_eq(PlatformSystem.install_base(p, 33), 13000)
	assert_eq(PlatformSystem.install_base(p, 39), 19000)
	assert_eq(PlatformSystem.install_base(p, 200), 26000)


func test_events_fire_on_exact_weeks() -> void:
	var s := Fixtures.new_state(1)
	var fired := {}
	for w: int in [12, 20, 60]:
		s.week = w
		var ctx := TickContext.new(s, Fixtures.tuning())
		PlatformSystem.tick(ctx)
		for e: Dictionary in ctx.events:
			if e["payload"].get("platform_id") == &"platform_fx_console":
				fired[w] = e["name"]
	assert_eq(fired, {12: &"platform_rumored", 20: &"platform_launched", 60: &"platform_retired"})


func test_writes_install_base_for_launched_platforms_only() -> void:
	var s := Fixtures.new_state(1)
	s.week = 0
	PlatformSystem.tick(TickContext.new(s, Fixtures.tuning()))
	assert_eq(s.market.platform_install_base[&"platform_fx_micro"], 70000)
	assert_false(s.market.platform_install_base.has(&"platform_fx_console"))
