class_name SliderTriple
extends VBoxContainer
## Three linked shares that always sum to Fixed.ONE_BP (Ruling P18).

signal values_committed(values: Array[int])

var _values: Array[int] = [0, 0, 0]
var _editable: bool = true
var _syncing: bool = false
var _dirty: bool = false


@warning_ignore("integer_division")
static func rebalance(values: Array[int], changed: int, new_value: int) -> Array[int]:
	var out: Array[int] = values.duplicate()
	var v: int = clampi(new_value, 0, Fixed.ONE_BP)
	var others: Array[int] = []
	for k: int in 3:
		if k != changed:
			others.append(k)
	var i: int = others[0]
	var j: int = others[1]
	var rest: int = Fixed.ONE_BP - v
	var old_sum: int = values[i] + values[j]
	var vj: int = rest / 2 if old_sum == 0 else rest * values[j] / old_sum
	out[changed] = v
	out[j] = vj
	out[i] = rest - vj
	return out


func setup(label_keys: Array[StringName], values: Array[int]) -> void:
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	_values = values.duplicate()
	for i: int in 3:
		var row := HBoxContainer.new()
		row.name = "Row_%d" % i
		var label := Label.new()
		label.name = "Label"
		label.text = tr(label_keys[i])
		label.custom_minimum_size.x = 60
		row.add_child(label)
		var slider := HSlider.new()
		slider.name = "Slider"
		slider.min_value = 0
		slider.max_value = Fixed.ONE_BP
		slider.step = 500
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.editable = _editable
		slider.value_changed.connect(_on_value_changed.bind(i))
		slider.drag_ended.connect(_on_drag_ended)
		row.add_child(slider)
		var value_label := Label.new()
		value_label.name = "Value"
		value_label.custom_minimum_size.x = 34
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)
		add_child(row)
	_sync()


func set_editable(editable: bool) -> void:
	_editable = editable
	for i: int in get_child_count():
		var slider: HSlider = _slider(i)
		if slider != null:
			slider.editable = editable


func values() -> Array[int]:
	return _values.duplicate()


func set_share(index: int, value: int) -> void:
	_values = rebalance(_values, index, value)
	_sync()
	values_committed.emit(values())


@warning_ignore("integer_division")
func _sync() -> void:
	_syncing = true
	for i: int in 3:
		var slider: HSlider = _slider(i)
		if slider == null:
			continue
		slider.set_value_no_signal(_values[i])
		(get_node("Row_%d/Value" % i) as Label).text = "%d%%" % (_values[i] / 100)
	_syncing = false


func _slider(i: int) -> HSlider:
	return get_node_or_null("Row_%d/Slider" % i) as HSlider


func _on_value_changed(v: float, index: int) -> void:
	if _syncing:
		return
	if not _editable:
		_sync()
		return
	_values = rebalance(_values, index, int(v))
	_dirty = true
	_sync()


func _on_drag_ended(_changed: bool) -> void:
	if not _editable or not _dirty:
		return
	_dirty = false
	values_committed.emit(values())
