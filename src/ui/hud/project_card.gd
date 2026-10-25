class_name ProjectCard
extends Control
## Floating project card (or "no project" chip). Reads state only through StateQueries.

const WIDTH := 210
const TILE_KINDS: Array[StringName] = [&"design", &"tech", &"art", &"audio", &"bug"]

const EVENT_SIGNALS: Array[StringName] = [
	&"week_ticked", &"project_changed", &"project_phase_changed", &"project_stage_changed", &"game_loaded",
]

var _name_keys: Dictionary[StringName, StringName] = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for node_name: String in ["Title", "Subtitle"]:
		var label: Label = get_node("%" + node_name)
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	(%Subtitle as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for kind: StringName in TILE_KINDS:
		var tile: Control = _tile(kind)
		var box: StyleBoxFlat = tile.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
		box.bg_color = UiPalette.tint(UiPalette.POINT_COLORS[kind])
		tile.add_theme_stylebox_override(&"panel", box)
		var number: Label = tile.find_child("Number", true, false)
		number.add_theme_color_override(&"font_color", UiPalette.ink(UiPalette.POINT_COLORS[kind]))
		number.clip_text = true
		(tile.find_child("Name", true, false) as Label).clip_text = true
	_translate()
	for sig_name: StringName in EVENT_SIGNALS:
		var sig: Signal = Signal(EventBus, sig_name)
		sig.connect(_on_event)
	_on_event({})


func _exit_tree() -> void:
	for sig_name: StringName in EVENT_SIGNALS:
		var sig: Signal = Signal(EventBus, sig_name)
		if sig.is_connected(_on_event):
			sig.disconnect(_on_event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_translate()
		_on_event({})


func _translate() -> void:
	%ChipText.text = tr("ui.status.no_project")
	for kind: StringName in TILE_KINDS:
		(_tile(kind).find_child("Name", true, false) as Label).text = tr("ui.point." + String(kind))


func _tile(kind: StringName) -> Control:
	return find_child("Tile_" + String(kind), true, false) as Control


func configure(name_keys: Dictionary[StringName, StringName]) -> void:
	_name_keys = name_keys
	_on_event({})


func tile_number(kind: StringName) -> Label:
	return _tile(kind).find_child("Number", true, false) as Label


func refresh(view: GameState) -> void:
	var info: Dictionary = StateQueries.project_status(view, StateQueries.active_project_id(view))
	var has_project: bool = not info.is_empty()
	%Card.visible = has_project
	%Chip.visible = not has_project
	if not has_project:
		return
	%Title.text = String(info["title"])
	%Subtitle.text = _subtitle(info["topic_id"], info["genre_id"])
	(%StageBar as StageBar).set_stages(info["stage_count"], info["stage"], info["progress"])
	%Stage.text = tr("ui.status.stage").format({
		"stage": info["stage"], "count": info["stage_count"], "progress": info["progress"],
	})
	for kind: StringName in TILE_KINDS:
		var key: String = "bugs" if kind == &"bug" else String(kind)
		tile_number(kind).text = str(info[key])


func _subtitle(topic_id: StringName, genre_id: StringName) -> String:
	var topic: String = tr(_name_keys[topic_id]) if _name_keys.has(topic_id) else ""
	var genre: String = tr(_name_keys[genre_id]) if _name_keys.has(genre_id) else ""
	if topic != "" and genre != "":
		return tr("ui.card.subtitle").format({"topic": topic, "genre": genre})
	return topic if topic != "" else genre


func _on_event(_payload: Dictionary) -> void:
	if GameRunner.session == null:
		return
	refresh(GameRunner.session.state)
