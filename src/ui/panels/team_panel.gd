class_name TeamPanel
extends PanelBase
## Team tab: staff rows, a hire row and the skill-tree placeholder.

const SKILLS: Array[StringName] = [&"design", &"tech", &"art", &"audio"]

var _rows_box: VBoxContainer
var _built_rows: Array[Dictionary] = []
var _rows_dirty: bool = true


func _init() -> void:
	super()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var soon: PanelContainer = UiBuild.chip(tr("ui.team.skill_tree_soon"), &"ChipPanel")
	soon.name = "SkillTree"
	soon.unique_name_in_owner = true
	_body.add_child(soon)
	soon.owner = self
	_build_hire_row()
	_rows_box = VBoxContainer.new()
	_rows_box.name = "Staff"
	_body.add_child(_rows_box)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_rows_dirty = true
		_retranslate_static()
		_refresh_now()


func refresh(view: GameState, t: TuningDef) -> void:
	if content == null:
		return
	var rows: Array[Dictionary] = StateQueries.staff_rows(view)
	if _rows_dirty or rows != _built_rows:
		_rows_dirty = false
		_built_rows = rows
		_rebuild_rows(rows, t)
	var office: OfficeDef = content.offices.get(StateQueries.player_office_id(view))
	var free: int = 0
	if office != null:
		for seat: SeatView in StateQueries.seat_views(view, office, content.equipment, t):
			if seat.staff_id == -1:
				free += 1
	(get_node("%FreeSeats") as Label).text = tr("ui.team.free_seats").format({"n": free})
	_update_hire(view, t)


func _retranslate_static() -> void:
	var soon: Node = get_node_or_null("%SkillTree")
	if soon != null:
		(soon.get_child(0) as Label).text = tr("ui.team.skill_tree_soon")
	var name_edit: LineEdit = get_node_or_null("%HireName") as LineEdit
	if name_edit != null:
		name_edit.placeholder_text = tr("ui.team.hire_name")
		(get_node("%Hire") as Button).text = tr("ui.team.hire")


func _build_hire_row() -> void:
	var row := PanelContainer.new()
	row.name = "HireRow"
	row.theme_type_variation = &"RowPanel"
	_body.add_child(row)
	var col := VBoxContainer.new()
	row.add_child(col)
	var edit := LineEdit.new()
	edit.name = "HireName"
	edit.unique_name_in_owner = true
	edit.placeholder_text = tr("ui.team.hire_name")
	edit.text_changed.connect(func(_t: String) -> void: _refresh_now())
	col.add_child(edit)
	edit.owner = self
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 10)
	col.add_child(line)
	var salary: Label = UiBuild.label("")
	salary.name = "HireSalary"
	salary.unique_name_in_owner = true
	salary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	salary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	salary.clip_text = true
	line.add_child(salary)
	salary.owner = self
	var free: Label = UiBuild.label("")
	free.name = "FreeSeats"
	free.unique_name_in_owner = true
	line.add_child(free)
	free.owner = self
	var hire := Button.new()
	hire.name = "Hire"
	hire.unique_name_in_owner = true
	hire.theme_type_variation = &"PrimaryButton"
	hire.text = tr("ui.team.hire")
	hire.pressed.connect(_on_hire)
	col.add_child(hire)
	hire.owner = self


func _hire_command(t: TuningDef) -> HireStaffCommand:
	var edit: LineEdit = get_node("%HireName") as LineEdit
	return HireStaffCommand.new(GameRunner.session.state.player_company_id, edit.text.strip_edges(), t.hire_offer_salary)


func _update_hire(view: GameState, t: TuningDef) -> void:
	(get_node("%HireSalary") as Label).text = tr("ui.team.salary").format({"money": UiFormat.money(t.hire_offer_salary)})
	var hire: Button = get_node("%Hire") as Button
	if (get_node("%HireName") as LineEdit).text.strip_edges().is_empty():
		hire.disabled = true
		hire.tooltip_text = ""
		return
	gate(hire, _hire_command(t))


func _on_hire() -> void:
	var session: GameSession = GameRunner.session
	if session == null:
		return
	if submit(_hire_command(session.tuning)):
		(get_node("%HireName") as LineEdit).text = ""
		_refresh_now()


func _rebuild_rows(rows: Array[Dictionary], t: TuningDef) -> void:
	for c: Node in _rows_box.get_children():
		_rows_box.remove_child(c)
		c.queue_free()
	for r: Dictionary in rows:
		_rows_box.add_child(_staff_row(r))


func _staff_row(r: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.name = "Staff_%d" % r["id"]
	row.theme_type_variation = &"RowPanel"
	var col := VBoxContainer.new()
	row.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 8)
	col.add_child(head)
	var name_label: Label = UiBuild.label(tr(String(r["name"])))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	if r["is_owner"]:
		var owner_chip: PanelContainer = UiBuild.chip(tr("ui.team.owner"))
		owner_chip.name = "Owner"
		head.add_child(owner_chip)
	if not r["has_computer"]:
		var nc: PanelContainer = UiBuild.chip(tr("ui.team.no_computer"), &"TagWarnPanel")
		nc.name = "NoComputer"
		head.add_child(nc)
	var money_line := HBoxContainer.new()
	money_line.add_theme_constant_override(&"separation", 10)
	col.add_child(money_line)
	money_line.add_child(UiBuild.label(tr("ui.team.salary").format({"money": UiFormat.money(r["salary"])})))
	money_line.add_child(UiBuild.label(tr("ui.team.morale").format({"n": r["morale"]})))
	var skills := HBoxContainer.new()
	skills.add_theme_constant_override(&"separation", 10)
	col.add_child(skills)
	var skill_values: Dictionary = r["skills"]
	for s: StringName in SKILLS:
		skills.add_child(UiBuild.label("%s %d" % [tr("ui.point.%s" % s), skill_values.get(s, 0)], &"SectionLabel"))
	return row
