extends GutTest

const HOST_SCENE: PackedScene = preload("res://src/ui/panels/panel_host.tscn")

var _host: PanelHost
var _panel: PanelBase


func before_each() -> void:
	TranslationServer.set_locale("en")
	GameRunner.session = GameSession.new(Fixtures.new_state(1), Fixtures.tuning())
	GameRunner.session.set_speed(0)


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


func _node(path: String) -> Node:
	return _panel.get_node_or_null(path)


func _texts(root: Node) -> String:
	var out: PackedStringArray = []
	for l: Label in UiFit.labels_under(root):
		out.append(l.text)
	return " | ".join(out)


func _company() -> Company:
	return _view().companies[_view().player_company_id]


func test_finance_values() -> void:
	Fixtures.add_staff(_view(), {"salary": 500})
	_company().money = 1234
	Fixtures.add_project(_view(), {"phase": Project.Phase.RELEASED, "revenue": 300, "release_week": 1})
	Fixtures.add_project(_view(), {"phase": Project.Phase.LIVE, "revenue": 200, "release_week": 2})
	_mount(FinancePanel.new(), &"finance")
	assert_string_contains(_texts(_node("%Cash")), tr("ui.finance.cash"))
	assert_string_contains(_texts(_node("%Cash")), UiFormat.money(1234))
	assert_string_contains(_texts(_node("%Salaries")), UiFormat.money(500))
	assert_string_contains(_texts(_node("%TotalRevenue")), UiFormat.money(500))
	assert_not_null(_node("%ByGame"))
	assert_null(_node("%None"))
	var ids: Array[Dictionary] = StateQueries.past_games(_view())
	for g: Dictionary in ids:
		var row: Node = _panel.find_child("Rev_%d" % g["id"], true, false)
		assert_not_null(row)
		assert_string_contains(_texts(row), UiFormat.money(g["revenue"]))
		assert_string_contains(_texts(row), String(g["title"]))


func test_finance_none_label() -> void:
	_mount(FinancePanel.new(), &"finance")
	assert_eq((_node("%None") as Label).text, tr("ui.finance.none"))


func test_market_hides_unannounced_platforms() -> void:
	_mount(MarketPanel.new(), &"market")
	assert_null(_panel.find_child("Platform_platform_fx_console", true, false))
	_view().week = 15
	EventBus.week_ticked.emit({})
	var row: Node = _panel.find_child("Platform_platform_fx_console", true, false)
	assert_not_null(row)
	assert_string_contains(_texts(row), tr("ui.market.status.rumored"))
	assert_null(row.find_child("InstallBase", true, false))


func test_market_install_base_on_sale() -> void:
	_view().week = 30
	_mount(MarketPanel.new(), &"market")
	var row: Node = _panel.find_child("Platform_platform_fx_console", true, false)
	var def: PlatformDef = Fixtures.content().platforms[&"platform_fx_console"]
	var base: int = PlatformSystem.install_base(def, 30, GameRunner.session.tuning)
	assert_string_contains(_texts(row), tr("ui.market.install_base").format({"units": UiFormat.thousands(base)}))


func test_buy_research() -> void:
	_company().research_points = 60
	_mount(MarketPanel.new(), &"market")
	var row: Node = _panel.find_child("Research_research_fx_scroll", true, false)
	var buy: Button = row.find_child("Buy", true, false) as Button
	assert_false(buy.disabled)
	buy.pressed.emit()
	assert_eq(_company().research_points, 10)
	row = _panel.find_child("Research_research_fx_scroll", true, false)
	assert_not_null(row.find_child("Done", true, false))
	assert_null(row.find_child("Buy", true, false))
	assert_string_contains((_node("%RP") as Label).text, "10")


func test_research_needs_prerequisite() -> void:
	_company().research_points = 999
	_mount(MarketPanel.new(), &"market")
	var row: Node = _panel.find_child("Research_research_fx_adventure", true, false)
	assert_null(row.find_child("Buy", true, false))
	assert_string_contains(_texts(row), tr("ui.market.needs").format({"names": tr("fx.research_fx_scroll")}))


func test_buy_disabled_without_rp() -> void:
	_company().research_points = 49
	_mount(MarketPanel.new(), &"market")
	var buy: Button = _panel.find_child("Research_research_fx_scroll", true, false).find_child("Buy", true, false) as Button
	assert_true(buy.disabled)
	assert_ne(buy.tooltip_text, "")
	_company().research_points = 50
	EventBus.money_changed.emit({})
	assert_false(buy.disabled)


func _assert_fits() -> void:
	var content: Control = _host.get_node("%Content") as Control
	assert_true(content.get_global_rect().encloses(_panel.get_global_rect()))
	for label: Label in UiFit.labels_under(_panel):
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF or label.clip_text:
			continue
		assert_true(UiFit.text_fits(label), "label '%s' clipped" % label.text)
	for b: Button in _panel.find_children("*", "Button", true, false):
		assert_true(UiFit.button_fits(b), "button '%s' clipped" % b.text)


func test_finance_fits_th() -> void:
	TranslationServer.set_locale("th")
	_company().money = 1234567
	Fixtures.add_staff(_view(), {"salary": 1234567})
	Fixtures.add_project(_view(), {"title": "เกมผจญภัยอวกาศสุดมหัศจรรย์", "phase": Project.Phase.LIVE,
		"release_week": 3, "units_sold": 9999999, "revenue": 9876543})
	_mount(FinancePanel.new(), &"finance")
	await wait_process_frames(2)
	_assert_fits()


func test_market_fits_th() -> void:
	TranslationServer.set_locale("th")
	_view().week = 30
	_company().research_points = 1234567
	_mount(MarketPanel.new(), &"market")
	await wait_process_frames(2)
	_assert_fits()
