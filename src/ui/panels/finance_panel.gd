class_name FinancePanel
extends PanelBase
## Finance tab: cash, monthly salaries, total sales revenue and revenue per released game.

var _built: Array = []
var _dirty: bool = true


func _init() -> void:
	super()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column: Node = _body.get_parent()
	var pad := MarginContainer.new()
	pad.name = "Pad"
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override(&"margin_right", 12)
	column.add_child(pad)
	column.move_child(pad, 0)
	column.remove_child(_body)
	pad.add_child(_body)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_dirty = true
		_refresh_now()


func refresh(view: GameState, _t: TuningDef) -> void:
	var fin: Dictionary = StateQueries.finance_view(view)
	var games: Array[Dictionary] = StateQueries.past_games(view)
	var key: Array = [fin, games]
	if not _dirty and key == _built:
		return
	_dirty = false
	_built = key
	for c: Node in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_stat_row("Cash", tr("ui.finance.cash"), UiFormat.money(fin["money"]))
	_stat_row("Salaries", tr("ui.finance.salaries"), UiFormat.money(fin["monthly_salaries"]))
	_stat_row("TotalRevenue", tr("ui.finance.total_revenue"), UiFormat.money(fin["total_revenue"]))
	var by_game := Label.new()
	by_game.text = tr("ui.finance.by_game")
	by_game.theme_type_variation = &"SectionLabel"
	_add_unique(by_game, "ByGame")
	if games.is_empty():
		var none := Label.new()
		none.text = tr("ui.finance.none")
		_add_unique(none, "None")
		return
	for g: Dictionary in games:
		_body.add_child(_game_row(g))


func _add_unique(node: Control, node_name: String) -> void:
	node.name = node_name
	node.unique_name_in_owner = true
	_body.add_child(node)
	node.owner = self


func _stat_row(node_name: String, caption: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = caption
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label := Label.new()
	value_label.name = "Value"
	value_label.text = value
	value_label.theme_type_variation = &"CardTitle"
	row.add_child(value_label)
	_add_unique(row, node_name)


func _game_row(g: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.name = "Rev_%d" % int(g["id"])
	row.theme_type_variation = &"RowPanel"
	var col := VBoxContainer.new()
	row.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.name = "Title"
	title.text = String(g["title"])
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var revenue := Label.new()
	revenue.name = "Revenue"
	revenue.text = UiFormat.money(g["revenue"])
	head.add_child(revenue)
	var units := Label.new()
	units.name = "Units"
	units.text = tr("ui.project.units").format({"units": UiFormat.thousands(g["units_sold"])})
	units.theme_type_variation = &"SectionLabel"
	col.add_child(units)
	return row
