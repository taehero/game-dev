class_name Bubble
extends Node2D

const COLORS: Dictionary[StringName, Color] = {
	&"design": Color("#22c55e"),
	&"tech": Color("#3b82f6"),
	&"art": Color("#f59e0b"),
	&"audio": Color("#a855f7"),
	&"bug": Color("#ef4444"),
}
const RISE_PX := 12
const LIFETIME_S := 1.2
const FADE_S := 0.4
const RADIUS := 3.0

var kind: StringName = &"design"

func _ready() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - RISE_PX, LIFETIME_S)
	tween.tween_property(self, "modulate:a", 0.0, FADE_S).set_delay(LIFETIME_S - FADE_S)
	tween.chain().tween_callback(queue_free)

func _draw() -> void:
	var c: Color = COLORS.get(kind, Color.WHITE)
	draw_circle(Vector2.ZERO, RADIUS, c)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 16, c.darkened(0.4), 1.0)
