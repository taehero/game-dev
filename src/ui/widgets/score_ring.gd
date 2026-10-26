class_name ScoreRing
extends Control
## Review score as an arc of 360 degrees x score/100 on a TRACK ring, number centred.

const RING_WIDTH: float = 4.0

var _score_x10: int = 0
var _number: Label


static func ring_color(score_x10: int) -> Color:
	if score_x10 >= 70:
		return UiPalette.SUCCESS
	if score_x10 >= 50:
		return UiPalette.WARNING
	return UiPalette.DANGER


func _init() -> void:
	custom_minimum_size = Vector2(40, 40)
	_number = Label.new()
	_number.theme_type_variation = &"TileNumber"
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_number.text = UiFormat.score(0)
	add_child(_number)


func set_score(score_x10: int) -> void:
	_score_x10 = score_x10
	_number.text = UiFormat.score(score_x10)
	queue_redraw()


func score() -> int:
	return _score_x10


func _draw() -> void:
	var centre: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) / 2.0 - RING_WIDTH / 2.0
	draw_arc(centre, radius, 0.0, TAU, 48, UiPalette.TRACK, RING_WIDTH, true)
	var frac: float = clampf(float(_score_x10) / 100.0, 0.0, 1.0)
	if frac > 0.0:
		draw_arc(centre, radius, -PI / 2.0, -PI / 2.0 + TAU * frac, 48, ring_color(_score_x10), RING_WIDTH, true)
