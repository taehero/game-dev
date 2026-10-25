extends GutTest


func test_buy_unlocks_and_spends() -> void:
	var s := Fixtures.new_state(1)
	var t := Fixtures.tuning()
	s.companies[1].research_points = 60
	var cmd := BuyResearchCommand.new(1, &"research_fx_scroll")
	assert_true(cmd.validate(s, t).ok)
	var ctx := TickContext.new(s, t)
	cmd.apply(ctx)
	assert_eq(s.companies[1].research_points, 10)
	assert_has(s.companies[1].unlocked, &"research_fx_scroll")
	assert_eq(ctx.events[0]["name"], &"research_done")


func test_rejections() -> void:
	var s := Fixtures.new_state(1)
	var t := Fixtures.tuning()
	assert_eq(BuyResearchCommand.new(99, &"research_fx_scroll").validate(s, t).reason_key, &"error.company_not_found")
	assert_eq(BuyResearchCommand.new(1, &"research_nope").validate(s, t).reason_key, &"error.research_not_found")
	assert_eq(BuyResearchCommand.new(1, &"research_fx_scroll").validate(s, t).reason_key, &"error.not_enough_rp")
	s.companies[1].research_points = 999
	assert_eq(BuyResearchCommand.new(1, &"research_fx_adventure").validate(s, t).reason_key, &"error.research_locked")
	s.companies[1].unlocked = [&"research_fx_scroll"]
	assert_eq(BuyResearchCommand.new(1, &"research_fx_scroll").validate(s, t).reason_key, &"error.research_done")
