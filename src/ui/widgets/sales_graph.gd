class_name SalesGraph
extends Control
## Weekly units as bars in UiPalette.MONEY. Bar height is relative to the largest week.

const GAP: float = 1.0

var _units: Array[int] = []


func _init() -> void:
	custom_minimum_size = Vector2(360, 120)


func set_series(units: Array[int]) -> void:
	_units = units.duplicate()
	queue_redraw()


func bar_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var peak: int = 0
	for u: int in _units:
		peak = maxi(peak, u)
	if peak <= 0:
		return out
	var w: float = size.x / float(_units.size())
	for i: int in _units.size():
		var h: float = size.y * float(maxi(_units[i], 0)) / float(peak)
		out.append(Rect2(w * float(i), size.y - h, w, h))
	return out


func _draw() -> void:
	for r: Rect2 in bar_rects():
		draw_rect(Rect2(r.position.x + GAP / 2.0, r.position.y, maxf(r.size.x - GAP, 0.5), r.size.y), UiPalette.MONEY)
