extends GutTest

var s: GameState
var t: TuningDef


func before_each() -> void:
	s = Fixtures.new_state(1)
	t = Fixtures.tuning()


func _run(cmd: Command) -> TickContext:
	var ctx := TickContext.new(s, t)
	cmd.apply(ctx)
	return ctx


func _starter() -> int:
	return GameRules.equipment_at_seat(s, 1, 0)


func test_buy_places_bought_equipment() -> void:
	var cmd := BuyEquipmentCommand.new(1, &"equipment_micro_1980", 1)
	assert_true(cmd.validate(s, t).ok)
	var ctx := _run(cmd)
	assert_eq(s.companies[1].money, 18500)
	var e: Equipment = s.equipment[GameRules.equipment_at_seat(s, 1, 1)]
	assert_eq(e.ownership, Equipment.Ownership.BOUGHT)
	assert_eq(e.value, 1500)
	assert_eq(e.bought_week, s.week)
	assert_eq(ctx.events[0]["name"], &"equipment_changed")
	assert_eq(ctx.events[1]["name"], &"money_changed")


func test_buy_rejections() -> void:
	var c: Callable = func(def: StringName, seat: int) -> StringName:
		return BuyEquipmentCommand.new(1, def, seat).validate(s, t).reason_key
	assert_eq(BuyEquipmentCommand.new(99, &"equipment_micro_1980", 1).validate(s, t).reason_key, &"error.company_not_found")
	assert_eq(c.call(&"x", 1), &"error.equipment_not_found")
	assert_eq(c.call(&"equipment_fx_future", 1), &"error.equipment_not_available")
	assert_eq(c.call(&"equipment_micro_1980", 2), &"error.invalid_seat")
	assert_eq(c.call(&"equipment_micro_1980", -1), &"error.invalid_seat")
	assert_eq(c.call(&"equipment_micro_1980", 0), &"error.seat_has_equipment")
	s.companies[1].money = 100
	assert_eq(c.call(&"equipment_micro_1980", 1), &"error.not_enough_money")


func test_lease_costs_nothing_now() -> void:
	var cmd := LeaseEquipmentCommand.new(1, &"equipment_micro_1980", 1)
	assert_true(cmd.validate(s, t).ok)
	_run(cmd)
	assert_eq(s.companies[1].money, 20000)
	var e: Equipment = s.equipment[GameRules.equipment_at_seat(s, 1, 1)]
	assert_eq(e.ownership, Equipment.Ownership.LEASED)
	assert_eq(e.value, 0)
	s.companies[1].money = 0
	assert_eq(LeaseEquipmentCommand.new(1, &"equipment_micro_1980", 1).validate(s, t).reason_key, &"error.seat_has_equipment")


func test_sell_bought_and_leased() -> void:
	var starter: int = _starter()
	var cmd := SellEquipmentCommand.new(starter)
	assert_true(cmd.validate(s, t).ok)
	var ctx := _run(cmd)
	assert_eq(s.companies[1].money, 20800)
	assert_false(s.equipment.has(starter))
	assert_eq(ctx.events[1]["name"], &"money_changed")
	var lid: int = Fixtures.add_equipment(s, {"seat_index": 1, "ownership": Equipment.Ownership.LEASED})
	_run(SellEquipmentCommand.new(lid))
	assert_eq(s.companies[1].money, 20800)
	assert_false(s.equipment.has(lid))
	assert_eq(SellEquipmentCommand.new(lid).validate(s, t).reason_key, &"error.equipment_not_found")


func test_sell_equipment_under_worker_stops_output() -> void:
	var pid: int = Fixtures.add_project(s)
	s.staff[s.owner_staff_id()].assigned_project_id = pid
	assert_eq(GameRules.working_staff(s, pid).size(), 1)
	_run(SellEquipmentCommand.new(_starter()))
	assert_eq(GameRules.working_staff(s, pid).size(), 0)
	assert_true(GameState.validate_dict(s.to_dict()))


func test_assign_seat() -> void:
	var sid: int = Fixtures.add_staff(s, {"seat_index": 1})
	var cmd := AssignSeatCommand.new(sid, -1)
	assert_true(cmd.validate(s, t).ok)
	_run(cmd)
	assert_eq(s.staff[sid].seat_index, -1)
	assert_eq(AssignSeatCommand.new(sid, 0).validate(s, t).reason_key, &"error.seat_taken")
	assert_eq(AssignSeatCommand.new(sid, 5).validate(s, t).reason_key, &"error.invalid_seat")
	assert_eq(AssignSeatCommand.new(99, 1).validate(s, t).reason_key, &"error.staff_not_found")
	assert_true(AssignSeatCommand.new(sid, 1).validate(s, t).ok)
