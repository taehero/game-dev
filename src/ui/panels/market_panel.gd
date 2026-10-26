class_name MarketPanel
extends PanelBase
## Market tab: platform status and install base, and research buying with RP.

const STATUS_KEYS: Dictionary[int, StringName] = {
	GameRules.PlatformStatus.RUMORED: &"ui.market.status.rumored",
	GameRules.PlatformStatus.ON_SALE: &"ui.market.status.on_sale",
	GameRules.PlatformStatus.RETIRED: &"ui.market.status.retired",
}

var _platforms: VBoxContainer
var _research: VBoxContainer
var _rp: Label
var _built_platforms: Array[Dictionary] = []
var _built_research: Array[Dictionary] = []
var _dirty: bool = true
var _buy_buttons: Dictionary[StringName, Button] = {}


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
	_platforms = _section("Platforms")
	_research = _section("Research")
	_research.add_child(_label(tr("ui.market.research"), &"SectionLabel"))
	_rp = Label.new()
	_rp.name = "RP"
	_rp.unique_name_in_owner = true
	_research.add_child(_rp)
	_rp.owner = self


func _section(node_name: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = node_name
	box.unique_name_in_owner = true
	_body.add_child(box)
	box.owner = self
	return box


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_dirty = true
		_refresh_now()


func refresh(view: GameState, t: TuningDef) -> void:
	var fin: Dictionary = StateQueries.finance_view(view)
	_rp.text = tr("ui.market.rp").format({"rp": fin["research_points"]})
	var platforms: Array[Dictionary] = []
	var research: Array[Dictionary] = []
	if content != null:
		platforms = StateQueries.platform_rows(view, content, t)
		research = StateQueries.research_rows(view, content)
	if _dirty or platforms != _built_platforms:
		_build_platforms(platforms)
	if _dirty or research != _built_research:
		_build_research(research)
	_dirty = false
	var company_id: int = view.player_company_id
	for id: StringName in _buy_buttons:
		gate(_buy_buttons[id], BuyResearchCommand.new(company_id, id))


func _clear_after(box: VBoxContainer, keep: int) -> void:
	var kids: Array[Node] = box.get_children()
	for i: int in range(keep, kids.size()):
		box.remove_child(kids[i])
		kids[i].queue_free()


func _label(text: String, variation: StringName = &"") -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	return l


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _build_platforms(rows: Array[Dictionary]) -> void:
	_built_platforms = rows
	_clear_after(_platforms, 0)
	_platforms.add_child(_label(tr("ui.market.platforms"), &"SectionLabel"))
	for r: Dictionary in rows:
		var status: int = r["status"]
		if status == GameRules.PlatformStatus.UNANNOUNCED:
			continue
		var row := PanelContainer.new()
		row.name = "Platform_%s" % r["id"]
		row.theme_type_variation = &"RowPanel"
		var col := VBoxContainer.new()
		row.add_child(col)
		var head := HBoxContainer.new()
		head.add_theme_constant_override(&"separation", 8)
		col.add_child(head)
		head.add_child(_wrap(_label(tr(r["name_key"]), &"CardTitle")))
		var chip := _label(tr(STATUS_KEYS[status]), &"SectionLabel")
		chip.name = "Status"
		head.add_child(chip)
		if status == GameRules.PlatformStatus.ON_SALE or status == GameRules.PlatformStatus.RETIRED:
			var base := _label(tr("ui.market.install_base").format({"units": UiFormat.thousands(r["install_base"])}))
			base.name = "InstallBase"
			col.add_child(_wrap(base))
		_platforms.add_child(row)


func _build_research(rows: Array[Dictionary]) -> void:
	_built_research = rows
	_buy_buttons.clear()
	_clear_after(_research, 2)
	(_research.get_child(0) as Label).text = tr("ui.market.research")
	for r: Dictionary in rows:
		var id: StringName = r["id"]
		var row := PanelContainer.new()
		row.name = "Research_%s" % id
		row.theme_type_variation = &"RowPanel"
		var col := VBoxContainer.new()
		row.add_child(col)
		var head := HBoxContainer.new()
		head.add_theme_constant_override(&"separation", 8)
		col.add_child(head)
		head.add_child(_wrap(_label(tr(r["name_key"]), &"CardTitle")))
		col.add_child(_label(tr("ui.market.research_cost").format({"cost": r["cost_rp"]}), &"SectionLabel"))
		if r["done"]:
			var chip := _label(tr("ui.market.done"), &"SectionLabel")
			chip.name = "Done"
			head.add_child(chip)
		elif r["available"]:
			var buy := Button.new()
			buy.name = "Buy"
			buy.text = tr("ui.market.research_buy")
			buy.pressed.connect(_on_buy.bind(id))
			head.add_child(buy)
			_buy_buttons[id] = buy
		else:
			var names: PackedStringArray = []
			for pre: StringName in r["prerequisites"]:
				names.append(tr(content.research[pre].name_key))
			var needs := _label(tr("ui.market.needs").format({"names": ", ".join(names)}))
			needs.name = "Needs"
			col.add_child(_wrap(needs))
		_research.add_child(row)


func _on_buy(id: StringName) -> void:
	submit(BuyResearchCommand.new(GameRunner.session.state.player_company_id, id))
	_refresh_now()
