class_name Bubble
extends Node2D
## A rising work bubble: emote icon plus an optional coloured "+N type" pill.

const COLORS: Dictionary[StringName, Color] = UiPalette.POINT_COLORS
const RISE_PX := 12
const LIFETIME_S := 1.2
const FADE_S := 0.4
const ICON_OFFSET := Vector2(0, -6)
const PILL_OFFSET := Vector2(9, -14)
const PILL_RADIUS := 6

var kind: StringName = &"design"
var amount: int = 0

var _pill: PanelContainer = null
var _label: Label = null
var _icon: Sprite2D = null
var _box: StyleBoxFlat = null


func _ready() -> void:
	if not COLORS.has(kind):
		push_warning("Bubble: unknown kind '%s'" % kind)
		queue_free()
		return
	var icon := Sprite2D.new()
	icon.name = "Icon"
	icon.texture = OfficeArt.atlas(OfficeArt.EMOTES[kind])
	icon.position = ICON_OFFSET
	add_child(icon)
	_icon = icon

	_pill = PanelContainer.new()
	_pill.name = "Pill"
	_pill.position = PILL_OFFSET
	var box := StyleBoxFlat.new()
	box.bg_color = COLORS.get(kind, Color.WHITE)
	box.set_corner_radius_all(PILL_RADIUS)
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	_pill.add_theme_stylebox_override(&"panel", box)
	_box = box
	_label = Label.new()
	_label.theme_type_variation = &"BubbleText"
	_pill.add_child(_label)
	add_child(_pill)
	var text := pill_text()
	_label.text = text
	_pill.visible = text != ""
	_pill.scale = Vector2.ONE / global_scale

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - RISE_PX, LIFETIME_S)
	tween.tween_property(self, "modulate:a", 0.0, FADE_S).set_delay(LIFETIME_S - FADE_S)
	tween.chain().tween_callback(queue_free)


## Merge a later event into this bubble (same staff, same frame).
func set_content(new_kind: StringName, new_amount: int) -> void:
	if not COLORS.has(new_kind):
		return
	kind = new_kind
	amount = new_amount
	if _label == null:
		return
	_icon.texture = OfficeArt.atlas(OfficeArt.EMOTES[kind])
	_box.bg_color = COLORS[kind]
	var text := pill_text()
	_label.text = text
	_pill.visible = text != ""


func pill_text() -> String:
	if kind == &"bug" and amount <= 1:
		return tr("ui.bubble.bug")
	if kind == &"bug" and amount > 1:
		return tr("ui.bubble.points").format({"amount": amount, "type": tr("ui.point.bug")})
	if amount > 0:
		return tr("ui.bubble.points").format({"amount": amount, "type": tr("ui.point.%s" % kind)})
	return ""
