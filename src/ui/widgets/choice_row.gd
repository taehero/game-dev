class_name ChoiceRow
extends HFlowContainer
## A row of toggle buttons: single choice (one ButtonGroup) or multi choice.

signal selection_changed

var _ids: Array[StringName] = []
var _multi: bool = false


func setup(ids: Array[StringName], labels: Array[String], multi: bool = false) -> void:
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	_ids = ids.duplicate()
	_multi = multi
	var group: ButtonGroup = null
	if not multi:
		group = ButtonGroup.new()
	for i: int in ids.size():
		var b := Button.new()
		b.name = "Choice_%s" % ids[i]
		b.text = labels[i]
		b.toggle_mode = true
		if group != null:
			b.button_group = group
		b.toggled.connect(_on_toggled)
		add_child(b)


func selected() -> StringName:
	for id: StringName in _ids:
		if _button(id).button_pressed:
			return id
	return &""


func selected_many() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _ids:
		if _button(id).button_pressed:
			out.append(id)
	return out


func select(id: StringName) -> void:
	var b: Button = _button(id)
	if b == null or b.disabled:
		return
	b.button_pressed = true


func set_choice_disabled(id: StringName, disabled_flag: bool, tooltip: String = "") -> void:
	var b: Button = _button(id)
	if b == null:
		return
	b.disabled = disabled_flag
	b.tooltip_text = tooltip if disabled_flag else ""


func _button(id: StringName) -> Button:
	return get_node_or_null("Choice_%s" % id) as Button


func _on_toggled(on: bool) -> void:
	# A single-choice change toggles the old button off and the new one on: report once.
	if _multi or on:
		selection_changed.emit()
