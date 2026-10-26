extends GutTest

const OUTLETS: Array[StringName] = [&"outlet_fx_a", &"outlet_fx_b", &"outlet_fx_c", &"outlet_fx_d"]
const KEYS: Array[Array] = [
	[&"review.strong.gameplay.1", &"review.weak.gameplay.1"],
	[&"review.strong.tech.2", &"review.weak.tech.1"],
	[&"review.strong.graphics.2", &"review.weak.story.2"],
	[&"review.strong.innovation.1", &"review.weak.graphics.1"],
]

var _saved_locale: String
var _pid: int


func before_each() -> void:
	ContentDB.use(Fixtures.content())
	_saved_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	GameRunner.start_new_game(7, "Studio")
	var view: GameState = GameRunner.session.state
	_pid = Fixtures.add_project(view, {"phase": Project.Phase.RELEASED, "title": "Space Quest", "weekly_units": [400, 300, 200], "units_sold": 900, "revenue": 45000, "user_score": 68})
	var p: Project = view.projects[_pid]
	for i: int in 4:
		var r := ReviewResult.new()
		r.outlet_id = OUTLETS[i]
		r.score_x10 = [75, 55, 30, 62][i]
		r.strength_key = KEYS[i][0]
		r.weakness_key = KEYS[i][1]
		p.review_results.append(r)


func after_each() -> void:
	GameRunner.session = null
	TranslationServer.set_locale(_saved_locale)


func _mount(card: PopupCard) -> Control:
	var screen := Control.new()
	screen.size = Vector2(640, 360)
	add_child_autofree(screen)
	screen.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return card.body().get_child(0) as Control


func test_review_popup_has_four_outlets_in_order() -> void:
	var v: Control = _mount(ReviewView.popup(_pid, Fixtures.content()))
	var cards: HBoxContainer = v.get_node("%Cards")
	assert_eq(cards.get_child_count(), 4)
	for i: int in 4:
		assert_eq(cards.get_child(i).name, StringName("Outlet_%s" % OUTLETS[i]))
	assert_eq((v.get_node("%Average") as Label).text, tr("ui.review.average").format({"score": "6.8"}))


func test_review_reason_text_formats_genre_and_platform() -> void:
	var v: Control = _mount(ReviewView.popup(_pid, Fixtures.content()))
	var cards: HBoxContainer = v.get_node("%Cards")
	var db: ContentDB = Fixtures.content()
	var vars: Dictionary = {"genre": tr(db.genres[&"genre_fx_action"].name_key), "platform": tr(db.platforms[&"platform_fx_micro"].name_key)}
	var weak: Label = cards.get_child(0).find_child("Disliked", true, false)
	assert_eq(weak.text, tr("review.weak.gameplay.1").format(vars))
	assert_true(weak.text.contains(vars["genre"]))
	var strong: Label = cards.get_child(1).find_child("Liked", true, false)
	assert_eq(strong.text, tr("review.strong.tech.2").format(vars))
	for c: Node in cards.get_children():
		assert_false((c.find_child("Liked", true, false) as Label).text.contains("{"))
		assert_false((c.find_child("Disliked", true, false) as Label).text.contains("{"))


func test_ring_colour_thresholds() -> void:
	assert_eq(ScoreRing.ring_color(75), UiPalette.SUCCESS)
	assert_eq(ScoreRing.ring_color(70), UiPalette.SUCCESS)
	assert_eq(ScoreRing.ring_color(55), UiPalette.WARNING)
	assert_eq(ScoreRing.ring_color(30), UiPalette.DANGER)
	var ring := ScoreRing.new()
	add_child_autofree(ring)
	ring.set_score(75)
	assert_eq(ring.score(), 75)
	assert_eq(ring.custom_minimum_size, Vector2(40, 40))


func test_sales_graph_bars_scale_to_max() -> void:
	var g := SalesGraph.new()
	add_child_autofree(g)
	g.set_series([400, 300, 200] as Array[int])
	var bars: Array[Rect2] = g.bar_rects()
	assert_eq(bars.size(), 3)
	assert_almost_eq(bars[0].size.y, g.size.y, 0.01)
	assert_almost_eq(bars[2].size.y, g.size.y / 2.0, 0.01)
	assert_almost_eq(bars[0].size.x, g.size.x / 3.0, 0.01)


func test_sales_graph_empty_draws_nothing() -> void:
	var g := SalesGraph.new()
	add_child_autofree(g)
	assert_eq(g.bar_rects().size(), 0)
	g.set_series([0, 0] as Array[int])
	assert_eq(g.bar_rects().size(), 0)


func test_sales_popup_no_data_label() -> void:
	var empty: int = Fixtures.add_project(GameRunner.session.state, {"phase": Project.Phase.RELEASED})
	var v: Control = _mount(SalesView.popup(empty, Fixtures.content()))
	assert_not_null(v.get_node_or_null("%NoData"))
	assert_null(v.get_node_or_null("%Graph"))
	var full: Control = _mount(SalesView.popup(_pid, Fixtures.content()))
	assert_null(full.get_node_or_null("%NoData"))
	assert_eq((full.get_node("%Graph") as SalesGraph).bar_rects().size(), 3)
	assert_eq((full.get_node("%Weeks") as Label).text, tr("ui.sales.weeks").format({"n": 3}))
	assert_true((full.get_node("%Totals") as Label).text.contains("45,000"))


func test_ok_closes_popup() -> void:
	for card: PopupCard in [ReviewView.popup(_pid, Fixtures.content()), SalesView.popup(_pid, Fixtures.content())]:
		var v: Control = _mount(card)
		watch_signals(card)
		(v.get_node("%Ok") as Button).pressed.emit()
		assert_signal_emitted(card, "closed")
		assert_true(card.is_queued_for_deletion())


func _assert_fits(card: PopupCard) -> void:
	_mount(card)
	await wait_frames(3)
	var rect: Rect2 = (card.get_node("%Card") as Control).get_global_rect()
	assert_true(Rect2(0, 0, 640, 360).encloses(rect), "card %s inside 640x360" % rect)
	for n: Node in card.body().find_children("*", "Label", true, false):
		var l: Label = n as Label
		if not l.clip_text:
			assert_lte(l.get_minimum_size().x, l.size.x + 0.5, "label not clipped: %s" % l.text)
		assert_true(rect.encloses(l.get_global_rect()), "label inside card: %s" % l.text)


func test_review_popup_fits_th() -> void:
	TranslationServer.set_locale("th")
	await _assert_fits(ReviewView.popup(_pid, Fixtures.content()))


func test_sales_popup_fits_th() -> void:
	TranslationServer.set_locale("th")
	await _assert_fits(SalesView.popup(_pid, Fixtures.content()))
