extends GutTest


func _base() -> Array:
	var s := Fixtures.new_state(4)
	var a := Fixtures.add_project(s)
	var b := Fixtures.add_project(s)
	return [s, a, b]


func _ok(edit: Callable) -> bool:
	var arr := _base()
	var d := Fixtures.json_round_trip((arr[0] as GameState).to_dict())
	edit.call(d, arr[1], arr[2], (arr[0] as GameState).player_company_id)
	return GameState.validate_dict(d)


func test_new_game_state_is_valid() -> void:
	assert_true(_ok(func(_d, _a, _b, _c) -> void: pass))


func test_rejects_unknown_parent_id() -> void:
	assert_false(_ok(func(d, a, _b, _c) -> void: d["projects"][str(a)]["parent_id"] = 9999))


func test_rejects_self_parent() -> void:
	assert_false(_ok(func(d, a, _b, _c) -> void: d["projects"][str(a)]["parent_id"] = a))


func test_rejects_bad_live_task() -> void:
	assert_false(_ok(func(d, a, _b, _c) -> void: d["projects"][str(a)]["live_task"] = "REFUND"))


func test_rejects_negative_live_task_left() -> void:
	assert_false(_ok(func(d, a, _b, _c) -> void: d["projects"][str(a)]["live_task_left"] = -1))


func test_rejects_negative_sales_base_units() -> void:
	assert_false(_ok(func(d, a, _b, _c) -> void: d["projects"][str(a)]["sales_base_units"] = -1))


func test_rejects_sentiment_out_of_range() -> void:
	assert_false(_ok(func(d, a, _b, _c) -> void: d["projects"][str(a)]["sentiment"] = 101))
	assert_false(_ok(func(d, a, _b, _c) -> void: d["projects"][str(a)]["sentiment"] = -101))


func test_rejects_promo_fatigue_out_of_range() -> void:
	assert_false(_ok(func(d, _a, _b, c) -> void: d["companies"][str(c)]["promo_fatigue"] = 101))
	assert_false(_ok(func(d, _a, _b, c) -> void: d["companies"][str(c)]["promo_fatigue"] = -1))


func test_accepts_dlc_with_valid_parent() -> void:
	assert_true(_ok(func(d, a, b, _c) -> void: d["projects"][str(a)]["parent_id"] = b))
