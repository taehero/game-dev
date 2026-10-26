extends GutTest

const HOST_SCENE: PackedScene = preload("res://src/ui/panels/panel_host.tscn")

var _host: PanelHost
var _panel: PanelBase


func before_each() -> void:
	TranslationServer.set_locale("en")
	GameRunner.session = GameSession.new(Fixtures.new_state(1), Fixtures.tuning())
	GameRunner.session.set_speed(0)
	OfficeFixtures.set_office(_view(), &"office_garage")


func after_each() -> void:
	GameRunner.session = null
	TranslationServer.set_locale("en")


func _view() -> GameState:
	return GameRunner.session.state


func _mount(panel: PanelBase, tab: StringName) -> PanelBase:
	_host = HOST_SCENE.instantiate()
	add_child_autofree(_host)
	_panel = panel
	_panel.configure(Fixtures.content())
	_host.set_panel(tab, _panel)
	_host.show_tab(tab)
	return _panel


func _team() -> TeamPanel:
	return _mount(TeamPanel.new(), &"team") as TeamPanel


func _equipment() -> EquipmentPanel:
	return _mount(EquipmentPanel.new(), &"equipment") as EquipmentPanel


func _node(path: String) -> Node:
	return _panel.get_node_or_null(path)


func _rows(prefix: String) -> Array[Node]:
	var out: Array[Node] = []
	for n: Node in _panel.find_children(prefix + "*", "PanelContainer", true, false):
		out.append(n)
	return out


func _hire(staff_name: String) -> void:
	(_node("%HireName") as LineEdit).text = staff_name
	(_node("%HireName") as LineEdit).text_changed.emit(staff_name)
	(_node("%Hire") as Button).pressed.emit()


func test_owner_row_chips() -> void:
	_team()
	var rows: Array[Node] = _rows("Staff_")
	assert_eq(rows.size(), 1)
	assert_not_null(rows[0].find_child("Owner", true, false))
	assert_null(rows[0].find_child("NoComputer", true, false))
	assert_not_null(_node("%SkillTree"))


func test_hire_adds_staff_without_computer() -> void:
	_team()
	_hire("Ada")
	var rows: Array[Node] = _rows("Staff_")
	assert_eq(rows.size(), 2)
	var hired: Node = rows[1]
	assert_not_null(hired.find_child("NoComputer", true, false))
	var texts: Array[String] = []
	for l: Label in UiFit.labels_under(hired):
		texts.append(l.text)
	assert_true(texts.has(tr("ui.team.salary").format({"money": UiFormat.money(800)})))
	assert_eq((_node("%HireName") as LineEdit).text, "")


func test_hire_disabled_when_name_blank() -> void:
	_team()
	(_node("%HireName") as LineEdit).text = "  "
	(_node("%HireName") as LineEdit).text_changed.emit("  ")
	assert_true((_node("%Hire") as Button).disabled)
	(_node("%HireName") as LineEdit).text = "Bo"
	(_node("%HireName") as LineEdit).text_changed.emit("Bo")
	assert_false((_node("%Hire") as Button).disabled)


func test_hire_disabled_when_garage_full() -> void:
	_team()
	_hire("Ada")
	(_node("%HireName") as LineEdit).text = "Bo"
	(_node("%HireName") as LineEdit).text_changed.emit("Bo")
	assert_true((_node("%Hire") as Button).disabled)
	assert_eq((_node("%Hire") as Button).tooltip_text, tr("error.no_free_seat"))
	assert_string_contains((_node("%FreeSeats") as Label).text, "0")


func test_buy_dev_kit() -> void:
	_view().week = 30
	_view().companies[_view().player_company_id].money = 10000
	_equipment()
	assert_not_null(_panel.find_child("Kit_platform_fx_console", true, false))
	assert_null(_panel.find_child("Kit_platform_fx_micro", true, false))
	(_panel.find_child("Kit_platform_fx_console", true, false).find_child("Buy", true, false) as Button).pressed.emit()
	assert_eq(_view().companies[_view().player_company_id].money, 7000)
	assert_null(_panel.find_child("Kit_platform_fx_console", true, false))
	assert_not_null(_panel.find_child("Owned_platform_fx_console", true, false))


func test_buy_disabled_without_money() -> void:
	_view().week = 30
	_view().companies[_view().player_company_id].money = 100
	_equipment()
	var buy: Button = _panel.find_child("Kit_platform_fx_console", true, false).find_child("Buy", true, false) as Button
	assert_true(buy.disabled)


func test_desks_show_tier_and_empty() -> void:
	_equipment()
	var desks: Array[Node] = _rows("Desk_")
	assert_eq(desks.size(), 2)
	var t0: Array[String] = []
	for l: Label in UiFit.labels_under(desks[0]):
		t0.append(l.text)
	assert_true(t0.has(tr("ui.equipment.computer").format({"tier": 1})))
	var t1: Array[String] = []
	for l: Label in UiFit.labels_under(desks[1]):
		t1.append(l.text)
	assert_true(t1.has(tr("ui.equipment.empty")))
	assert_not_null(desks[1].find_child("NoComputer", true, false))
	assert_null(desks[0].find_child("NoComputer", true, false))
	assert_not_null(_node("%BuySoon"))


func _assert_fits() -> void:
	var content: Control = _host.get_node("%Content") as Control
	assert_true(content.get_global_rect().encloses(_panel.get_global_rect()))
	for label: Label in UiFit.labels_under(_panel):
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF or label.clip_text:
			continue
		assert_true(UiFit.text_fits(label), "label '%s' clipped" % label.text)
	for b: Node in _panel.find_children("*", "Button", true, false):
		assert_true(UiFit.button_fits(b as Button), "button '%s' clipped" % (b as Button).text)


func test_team_fits_th() -> void:
	TranslationServer.set_locale("th")
	Fixtures.add_staff(_view(), {"name": "สมชาย ใจดีมากเลยครับ", "seat_index": 1, "salary": 123456})
	_team()
	await wait_process_frames(2)
	_assert_fits()


func test_equipment_fits_th() -> void:
	TranslationServer.set_locale("th")
	_view().week = 30
	_equipment()
	await wait_process_frames(2)
	_assert_fits()


func test_buy_soon_retranslates() -> void:
	_equipment()
	TranslationServer.set_locale("th")
	assert_eq((_node("%BuySoon").get_child(0) as Label).text, tr("ui.equipment.buy_soon"))
	assert_ne(tr("ui.equipment.buy_soon"), "ui.equipment.buy_soon")
