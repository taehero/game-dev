extends GutTest


func test_buy_console_kit_after_launch() -> void:
	var s := Fixtures.new_state(1)
	var t := Fixtures.tuning()
	s.week = 20
	var cmd := BuyDevKitCommand.new(1, &"platform_fx_console")
	assert_true(cmd.validate(s, t).ok)
	var ctx := TickContext.new(s, t)
	cmd.apply(ctx)
	assert_eq(s.companies[1].money, 20000 - 3000)
	assert_true(GameRules.has_dev_kit(s, Fixtures.content(), 1, &"platform_fx_console"))
	assert_eq(cmd.validate(s, t).reason_key, &"error.dev_kit_owned")
	assert_eq(ctx.events[0]["name"], &"money_changed")


func test_rejections() -> void:
	var s := Fixtures.new_state(1)
	var t := Fixtures.tuning()
	assert_eq(BuyDevKitCommand.new(99, &"platform_fx_console").validate(s, t).reason_key, &"error.company_not_found")
	assert_eq(BuyDevKitCommand.new(1, &"platform_nope").validate(s, t).reason_key, &"error.platform_not_found")
	assert_eq(BuyDevKitCommand.new(1, &"platform_fx_console").validate(s, t).reason_key, &"error.platform_not_on_sale")
	assert_eq(BuyDevKitCommand.new(1, &"platform_fx_micro").validate(s, t).reason_key, &"error.dev_kit_owned")
	s.week = 20
	s.companies[1].money = 100
	assert_eq(BuyDevKitCommand.new(1, &"platform_fx_console").validate(s, t).reason_key, &"error.not_enough_money")
