class_name BubbleLayer
extends Node2D

const MAX_BUBBLES := 24
## Two vertical slots; the pill of one is about 12px tall.
const SLOTS := 2
const SLOT_STEP_PX := 14

var _spawned: int = 0

func spawn(at: Vector2, kind: StringName, amount: int = 0) -> Bubble:
	if not Bubble.COLORS.has(kind):
		push_warning("BubbleLayer: unknown bubble kind '%s'" % kind)
		return null
	while live_count() >= MAX_BUBBLES:
		_free_oldest()
	var b := Bubble.new()
	b.kind = kind
	b.amount = amount
	b.position = at + Vector2(0, -(_spawned % SLOTS) * SLOT_STEP_PX)
	_spawned += 1
	add_child(b)
	return b

func live_count() -> int:
	var n: int = 0
	for child: Node in get_children():
		if not child.is_queued_for_deletion():
			n += 1
	return n

func _free_oldest() -> void:
	for child: Node in get_children():
		if not child.is_queued_for_deletion():
			child.queue_free()
			return
