extends GutTest

const POPUP_SCENE: PackedScene = preload("res://src/ui/panels/popup_card.tscn")


func _popup() -> Array:
	var screen: Control = Control.new()
	screen.size = Vector2(640, 360)
	add_child_autofree(screen)
	var popup: PopupCard = POPUP_SCENE.instantiate()
	screen.add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return [screen, popup]


func test_popup_open_centres_card() -> void:
	var popup: PopupCard = _popup()[1]
	popup.card_size = Vector2(400, 200)
	popup.open("T")
	await wait_frames(1)
	var card: Control = popup.get_node("%Card")
	var c: Vector2 = card.get_global_rect().get_center()
	assert_almost_eq(c.x, 320.0, 1.5)
	assert_almost_eq(c.y, 180.0, 1.5)
	assert_eq((popup.get_node("%Title") as Label).text, "T")


func test_backdrop_blocks_input() -> void:
	var popup: PopupCard = _popup()[1]
	await wait_frames(1)
	var backdrop: ColorRect = popup.get_node("Backdrop")
	assert_eq(backdrop.color, UiPalette.BACKDROP)
	assert_eq(backdrop.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(backdrop.get_global_rect(), Rect2(0, 0, 640, 360))


func test_popup_close_emits_and_frees() -> void:
	var popup: PopupCard = _popup()[1]
	watch_signals(popup)
	popup.close()
	assert_signal_emitted(popup, "closed")
	assert_true(popup.is_queued_for_deletion())


func test_not_closable_hides_close() -> void:
	var screen: Control = Control.new()
	screen.size = Vector2(640, 360)
	add_child_autofree(screen)
	var popup: PopupCard = POPUP_SCENE.instantiate()
	popup.closable = false
	screen.add_child(popup)
	popup.open("T")
	assert_false((popup.get_node("%Close") as Button).visible)


func test_body_is_vbox() -> void:
	var popup: PopupCard = _popup()[1]
	assert_true(popup.body() is VBoxContainer)


func test_open_before_add_child_is_centred() -> void:
	var screen: Control = Control.new()
	screen.size = Vector2(640, 360)
	add_child_autofree(screen)
	var popup: PopupCard = POPUP_SCENE.instantiate()
	popup.open("T")
	screen.add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await wait_frames(2)
	var c: Vector2 = (popup.get_node("%Card") as Control).get_global_rect().get_center()
	assert_almost_eq(c.x, 320.0, 1.5)
	assert_almost_eq(c.y, 180.0, 1.5)


func test_closable_setter_updates_visibility() -> void:
	var popup: PopupCard = _popup()[1]
	popup.closable = false
	assert_false((popup.get_node("%Close") as Button).visible)


func test_card_stays_centred_when_content_grows_it() -> void:
	var popup: PopupCard = _popup()[1]
	popup.card_size = Vector2(200, 80)
	popup.open("T")
	await wait_frames(1)
	var filler := Control.new()
	filler.custom_minimum_size = Vector2(300, 220)
	popup.body().add_child(filler)
	await wait_frames(2)
	var card: Control = popup.get_node("%Card")
	assert_gte(card.size.x, 300.0)
	var c: Vector2 = card.get_global_rect().get_center()
	assert_almost_eq(c.x, 320.0, 1.5)
	assert_almost_eq(c.y, 180.0, 1.5)
