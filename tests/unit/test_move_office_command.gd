extends GutTest

var s: GameState
var t: TuningDef


func before_each() -> void:
	s = Fixtures.new_state(1)
	t = Fixtures.tuning()


func test_move_to_small_office() -> void:
	var cmd := MoveOfficeCommand.new(1, &"office_small")
	assert_true(cmd.validate(s, t).ok)
	var ctx := TickContext.new(s, t)
	cmd.apply(ctx)
	assert_eq(s.companies[1].money, 18500)
	assert_eq(GameRules.office_seats(s, Fixtures.content(), 1), 5)
	assert_eq(ctx.events[0]["name"], &"equipment_changed")
	assert_eq(ctx.events[1]["name"], &"money_changed")


func test_move_to_smaller_office_refused() -> void:
	s.companies[1].office_id = &"office_small"
	Fixtures.add_staff(s, {"seat_index": 3})
	assert_eq(MoveOfficeCommand.new(1, &"office_garage").validate(s, t).reason_key, &"error.office_too_small")


func test_move_rejections() -> void:
	assert_eq(MoveOfficeCommand.new(1, &"office_nope").validate(s, t).reason_key, &"error.office_not_found")
	assert_eq(MoveOfficeCommand.new(1, &"office_garage").validate(s, t).reason_key, &"error.office_current")
	s.companies[1].money = 0
	assert_eq(MoveOfficeCommand.new(1, &"office_small").validate(s, t).reason_key, &"error.not_enough_money")
