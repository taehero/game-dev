extends GutTest

var _saved_locale: String


func before_each() -> void:
	ContentDB.use(Fixtures.content())
	_saved_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_each() -> void:
	GameRunner.session = null
	TranslationServer.set_locale(_saved_locale)


func _triple(a: int, b: int, c: int) -> Array[int]:
	var out: Array[int] = [a, b, c]
	return out


func test_rebalance_keeps_sum() -> void:
	var triples: Array[Array] = [
		[0, 3334, 3333, 3333], [0, 10000, 0, 0], [0, 0, 10000, 0], [0, 0, 0, 10000],
		[0, 5000, 3000, 2000], [0, 3333, 3333, 3334],
	]
	for t: Array in triples:
		var base: Array[int] = _triple(int(t[1]), int(t[2]), int(t[3]))
		for changed: int in 3:
			for nv: int in [0, 500, 3333, 10000, 12000]:
				var out: Array[int] = SliderTriple.rebalance(base, changed, nv)
				assert_eq(out[0] + out[1] + out[2], 10000, "%s c%d v%d" % [base, changed, nv])
				assert_true(out[0] >= 0 and out[1] >= 0 and out[2] >= 0, "%s c%d v%d" % [base, changed, nv])


func test_rebalance_proportional() -> void:
	assert_eq(SliderTriple.rebalance(_triple(5000, 3000, 2000), 0, 6000), _triple(6000, 2400, 1600))


func test_rebalance_both_zero() -> void:
	assert_eq(SliderTriple.rebalance(_triple(10000, 0, 0), 0, 5000), _triple(5000, 2500, 2500))
	assert_eq(SliderTriple.rebalance(_triple(10000, 0, 0), 0, 4500), _triple(4500, 2750, 2750))


func test_rebalance_remainder_to_lower_index() -> void:
	assert_eq(SliderTriple.rebalance(_triple(3334, 3333, 3333), 2, 0), _triple(5001, 4999, 0))


func _make_triple() -> SliderTriple:
	var st := SliderTriple.new()
	add_child_autofree(st)
	var keys: Array[StringName] = [&"ui.point.design", &"ui.point.tech", &"ui.point.art"]
	st.setup(keys, _triple(3334, 3333, 3333))
	return st


func test_slider_triple_set_share_emits_once() -> void:
	var st: SliderTriple = _make_triple()
	watch_signals(st)
	st.set_share(0, 6000)
	assert_signal_emit_count(st, "values_committed", 1)
	assert_eq(st.values(), _triple(6000, 2000, 2000))
	var row: Node = st.get_node("Row_1")
	assert_eq((row.get_node("Value") as Label).text, "20%")
	assert_eq(st.get_child_count(), 3)


func test_slider_triple_not_editable_ignores_input() -> void:
	var st: SliderTriple = _make_triple()
	st.set_editable(false)
	watch_signals(st)
	var slider: HSlider = st.get_node("Row_0/Slider") as HSlider
	assert_false(slider.editable)
	slider.value = 9000
	slider.drag_ended.emit(true)
	assert_eq(st.values(), _triple(3334, 3333, 3333))
	assert_signal_not_emitted(st, "values_committed")


func test_slider_drag_rebalances_and_commits() -> void:
	var st: SliderTriple = _make_triple()
	watch_signals(st)
	var slider: HSlider = st.get_node("Row_0/Slider") as HSlider
	slider.value = 5000
	assert_signal_not_emitted(st, "values_committed")
	slider.drag_ended.emit(true)
	assert_signal_emit_count(st, "values_committed", 1)
	var v: Array[int] = st.values()
	assert_eq(v[0] + v[1] + v[2], 10000)
	assert_eq(v[0], 5000)


func test_choice_row_single_and_multi() -> void:
	var ids: Array[StringName] = [&"a", &"b", &"c"]
	var labels: Array[String] = ["A", "B", "C"]
	var single := ChoiceRow.new()
	add_child_autofree(single)
	single.setup(ids, labels)
	assert_eq(single.selected(), &"")
	watch_signals(single)
	single.select(&"b")
	assert_eq(single.selected(), &"b")
	assert_signal_emit_count(single, "selection_changed", 1)
	single.select(&"c")
	assert_eq(single.selected(), &"c")
	assert_false((single.get_node("Choice_b") as Button).button_pressed)
	var multi := ChoiceRow.new()
	add_child_autofree(multi)
	multi.setup(ids, labels, true)
	multi.select(&"c")
	multi.select(&"a")
	assert_eq(multi.selected_many(), [&"a", &"c"] as Array[StringName])


func test_choice_row_disabled_choice_not_selectable() -> void:
	var ids: Array[StringName] = [&"a", &"b"]
	var labels: Array[String] = ["A", "B"]
	var row := ChoiceRow.new()
	add_child_autofree(row)
	row.setup(ids, labels)
	row.set_choice_disabled(&"b", true, "nope")
	var btn: Button = row.get_node("Choice_b") as Button
	assert_true(btn.disabled)
	assert_eq(btn.tooltip_text, "nope")
	row.select(&"b")
	assert_eq(row.selected(), &"")


func test_format_score_signed_money() -> void:
	assert_eq(UiFormat.score(75), "7.5")
	assert_eq(UiFormat.score(100), "10.0")
	assert_eq(UiFormat.score(0), "0.0")
	assert_eq(UiFormat.signed(5), "+5")
	assert_eq(UiFormat.signed(-3), "-3")
	assert_eq(UiFormat.signed(0), "0")
	assert_eq(UiFormat.money(1234), "$1,234")
	assert_eq(UiFormat.money(-1234), "$-1,234")


func _make_panel() -> PanelBase:
	GameRunner.start_new_game(1, "T")
	var p := PanelBase.new()
	add_child_autofree(p)
	return p


func test_panel_base_submit_shows_reason() -> void:
	var p: PanelBase = _make_panel()
	var cid: int = GameRunner.session.state.player_company_id
	assert_false(p.submit(HireStaffCommand.new(cid, "X", 0)))
	assert_eq(p.status_label().text, tr("error.invalid_salary"))
	assert_true(p.submit(HireStaffCommand.new(cid, "X", 100)))
	assert_eq(p.status_label().text, "")


func test_panel_base_gate_disables_with_tooltip() -> void:
	var p: PanelBase = _make_panel()
	var cid: int = GameRunner.session.state.player_company_id
	var b := Button.new()
	p.body().add_child(b)
	p.gate(b, HireStaffCommand.new(cid, "X", 0))
	assert_true(b.disabled)
	assert_eq(b.tooltip_text, tr("error.invalid_salary"))
	p.gate(b, HireStaffCommand.new(cid, "X", 100))
	assert_false(b.disabled)
	assert_eq(b.tooltip_text, "")


class _Probe extends PanelBase:
	var calls: int = 0

	func refresh(_view: GameState, _t: TuningDef) -> void:
		calls += 1


func test_panel_base_refreshes_on_events_and_disconnects() -> void:
	GameRunner.start_new_game(1, "T")
	var p := _Probe.new()
	add_child_autofree(p)
	var before: int = p.calls
	EventBus.dispatch(&"money_changed", {})
	assert_eq(p.calls, before + 1)
	assert_eq(p.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	remove_child(p)
	EventBus.dispatch(&"money_changed", {})
	assert_eq(p.calls, before + 1)
	p.free()
