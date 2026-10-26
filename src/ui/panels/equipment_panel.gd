class_name EquipmentPanel
extends PanelBase
## Equipment tab: dev kits to buy, owned platforms, desks and the computer-shop placeholder.

const STATUS_KEYS: Dictionary[int, StringName] = {
	GameRules.PlatformStatus.RUMORED: &"ui.market.status.rumored",
	GameRules.PlatformStatus.ON_SALE: &"ui.market.status.on_sale",
}

var _kits: VBoxContainer
var _owned: HFlowContainer
var _desks: VBoxContainer
var _built: Array = []
var _dirty: bool = true


func _init() -> void:
	super()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_kits = _section("DevKits")
	_owned = HFlowContainer.new()
	_owned.name = "Owned"
	_owned.unique_name_in_owner = true
	_body.add_child(_owned)
	_owned.owner = self
	_desks = _section("Desks")
	var soon: PanelContainer = UiBuild.chip(tr("ui.equipment.buy_soon"), &"ChipPanel")
	soon.name = "BuySoon"
	soon.unique_name_in_owner = true
	_body.add_child(soon)
	soon.owner = self


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_dirty = true
		var soon: Node = get_node_or_null("%BuySoon")
		if soon != null:
			(soon.get_child(0) as Label).text = tr("ui.equipment.buy_soon")
		_refresh_now()


func _section(node_name: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = node_name
	box.unique_name_in_owner = true
	_body.add_child(box)
	box.owner = self
	return box


func refresh(view: GameState, t: TuningDef) -> void:
	if content == null:
		return
	var platforms: Array[Dictionary] = StateQueries.platform_rows(view, content, t)
	var office: OfficeDef = content.offices.get(StateQueries.player_office_id(view))
	var seats: Array[SeatView] = []
	if office != null:
		seats = StateQueries.seat_views(view, office, content.equipment, t)
	var key: Array = []
	for p: Dictionary in platforms:
		key.append([p["id"], p["status"], p["dev_kit_cost"], p["owned"]])
	for s: SeatView in seats:
		key.append([s.seat_index, s.staff_id, s.computer_tier])
	for s: SeatView in seats:
		if s.staff_id != -1:
			key.append(StateQueries.staff_name(view, s.staff_id))
	if _dirty or key != _built:
		_dirty = false
		_built = key
		_rebuild(view, platforms, seats)
	for p: Dictionary in platforms:
		var row: Node = _kits.get_node_or_null("Kit_%s" % p["id"])
		if row != null:
			var buy: Button = row.find_child("Buy", true, false) as Button
			gate(buy, BuyDevKitCommand.new(StateQueries.player_company_id(view), p["id"]))


func _clear(box: Control) -> void:
	for c: Node in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _rebuild(view: GameState, platforms: Array[Dictionary], seats: Array[SeatView]) -> void:
	_clear(_kits)
	_clear(_owned)
	_clear(_desks)
	_kits.add_child(UiBuild.label(tr("ui.equipment.dev_kits"), &"SectionLabel"))
	_owned.add_child(UiBuild.label(tr("ui.equipment.platforms_owned"), &"SectionLabel"))
	_desks.add_child(UiBuild.label(tr("ui.equipment.desks"), &"SectionLabel"))
	for p: Dictionary in platforms:
		var status: int = p["status"]
		if p["owned"]:
			if status == GameRules.PlatformStatus.ON_SALE:
				var chip: PanelContainer = UiBuild.chip(tr(p["name_key"]))
				chip.name = "Owned_%s" % p["id"]
				_owned.add_child(chip)
		elif p["dev_kit_cost"] > 0 and STATUS_KEYS.has(status):
			_kits.add_child(_kit_row(p))
	for s: SeatView in seats:
		_desks.add_child(_desk_row(view, s))


func _kit_row(p: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.name = "Kit_%s" % p["id"]
	row.theme_type_variation = &"RowPanel"
	var col := VBoxContainer.new()
	row.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 8)
	col.add_child(head)
	var name_label: Label = UiBuild.label(tr(p["name_key"]))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(UiBuild.label(tr(STATUS_KEYS[p["status"]]), &"SectionLabel"))
	var buy := Button.new()
	buy.name = "Buy"
	buy.text = tr("ui.equipment.buy_kit").format({"money": UiFormat.money(p["dev_kit_cost"])})
	var pid: StringName = p["id"]
	buy.pressed.connect(func() -> void: _buy(pid))
	col.add_child(buy)
	return row


func _buy(platform_id: StringName) -> void:
	if submit(BuyDevKitCommand.new(StateQueries.player_company_id(GameRunner.session.state), platform_id)):
		_refresh_now()


func _desk_row(view: GameState, s: SeatView) -> Control:
	var row := PanelContainer.new()
	row.name = "Desk_%d" % s.seat_index
	row.theme_type_variation = &"RowPanel"
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 8)
	row.add_child(line)
	line.add_child(UiBuild.label(tr("ui.equipment.desk").format({"n": s.seat_index + 1}), &"SectionLabel"))
	var who: String = tr("ui.equipment.empty")
	if s.staff_id != -1 and StateQueries.staff_name(view, s.staff_id) != "":
		who = tr(StateQueries.staff_name(view, s.staff_id))
	var who_label: Label = UiBuild.label(who)
	who_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who_label.clip_text = true
	who_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(who_label)
	if s.computer_tier > 0:
		line.add_child(UiBuild.label(tr("ui.equipment.computer").format({"tier": s.computer_tier})))
	else:
		var nc: PanelContainer = UiBuild.chip(tr("ui.team.no_computer"), &"TagWarnPanel")
		nc.name = "NoComputer"
		line.add_child(nc)
	return row
