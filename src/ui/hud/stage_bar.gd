class_name StageBar
extends Control
## Segmented stage progress: done = SUCCESS, current = ACCENT partial fill, future = TRACK.

const GAP := 3
const RADIUS := 3

var _count: int = 1
var _current: int = 1
var _progress: int = 0


func _init() -> void:
	custom_minimum_size = Vector2(0, 6)


func set_stages(count: int, current: int, progress_pct: int) -> void:
	_count = maxi(count, 1)
	_current = clampi(current, 1, _count)
	_progress = clampi(progress_pct, 0, 100)
	queue_redraw()


func segment_count() -> int:
	return _count


func segment_fill(i: int) -> int:
	if i < _current - 1:
		return 100
	if i == _current - 1:
		return _progress
	return 0


func segment_color(i: int) -> Color:
	if i < _current - 1:
		return UiPalette.SUCCESS
	if i == _current - 1:
		return UiPalette.ACCENT
	return UiPalette.TRACK


func _draw() -> void:
	var total_gap: float = float(GAP * (_count - 1))
	var seg_w: float = (size.x - total_gap) / float(_count)
	if seg_w <= 0.0:
		return
	for i: int in _count:
		var x: float = float(i) * (seg_w + float(GAP))
		_draw_round(Rect2(x, 0.0, seg_w, size.y), UiPalette.TRACK)
		var fill: int = segment_fill(i)
		if fill > 0:
			_draw_round(Rect2(x, 0.0, seg_w * float(fill) / 100.0, size.y), segment_color(i))


func _draw_round(r: Rect2, c: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = c
	box.set_corner_radius_all(RADIUS)
	box.anti_aliasing = true
	draw_style_box(box, r)
