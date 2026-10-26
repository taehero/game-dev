extends GutTest

const KIND: StringName = &"pevent_fx_a"
const PLAY := Rect2(0, 0, 640, 360)

var _saved_locale: String
var _pid: int = -1
var _did: int = -1
var _tuning: TuningDef


func before_each() -> void:
	_saved_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var ev := Fixtures.pevent(KIND, {&"bugs": 3, &"progress_bp": 500}, {}, {&"hype": -2, &"morale": 1})
	_tuning = Fixtures.tuning()
	var s: GameState = Fixtures.new_state(3)
	_pid = Fixtures.add_project(s, {"phase": Project.Phase.POLISH, "bugs": 30})
	var d := Decision.new()
	d.id = s.alloc_id()
	d.kind = KIND
	d.related_ids.assign([_pid])
	d.deadline_week = s.week + 4
	d.option_keys.assign(ev.option_keys)
	s.pending_decisions.append(d)
	_did = d.id
	ContentDB.use(Fixtures.content_plus([ev] as Array[Resource]))
	GameRunner.session = GameSession.new(s, _tuning)
	GameRunner.session.speed = 0


func after_each() -> void:
	GameRunner.session = null
	TranslationServer.set_locale(_saved_locale)
	ContentDB.use(Fixtures.content())


func _mount(popup: PopupCard) -> Node:
	var screen := Control.new()
	screen.size = Vector2(640, 360)
	add_child_autofree(screen)
	screen.add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return popup.body().get_child(0)


func _hunt() -> Array:
	var popup: PopupCard = BugHuntView.popup(_pid, _tuning, PLAY, 7)
	return [popup, _mount(popup)]


func test_event_popup_lists_options_with_effects() -> void:
	var popup: PopupCard = EventView.popup(_did, ContentDB.active())
	var v: EventView = _mount(popup)
	var o0: Button = v.get_node("Option_0")
	assert_string_contains(o0.text, tr("ui.effect.bugs").format({"n": "+3"}))
	assert_string_contains(o0.text, tr("ui.effect.progress_bp").format({"n": "+5"}))
	assert_string_contains((v.get_node("Option_1") as Button).text, tr("ui.effect.none"))
	assert_string_contains((v.get_node("Option_2") as Button).text, tr("ui.effect.hype").format({"n": "-2"}))


func test_choose_applies_and_closes() -> void:
	var popup: PopupCard = EventView.popup(_did, ContentDB.active())
	var v: EventView = _mount(popup)
	GameRunner.session.state.projects[_pid].bugs = 10
	var before: int = 10
	assert_true(v.choose(0))
	assert_eq(GameRunner.session.state.projects[_pid].bugs, before + 3)
	assert_true(popup.is_queued_for_deletion())


func test_event_popup_not_closable() -> void:
	var popup: PopupCard = EventView.popup(_did, ContentDB.active())
	_mount(popup)
	assert_false(popup.closable)
	assert_false((popup.get_node("%Close") as Button).visible)


func test_offer_start_emits_and_closes() -> void:
	var popup: PopupCard = BugHuntOffer.popup(_pid, _tuning)
	var o: BugHuntOffer = _mount(popup)
	watch_signals(o)
	(o.get_node("%Start") as Button).pressed.emit()
	assert_signal_emitted_with_parameters(o, "hunt_requested", [_pid])
	assert_true(popup.is_queued_for_deletion())


func test_offer_skip_submits_nothing() -> void:
	var popup: PopupCard = BugHuntOffer.popup(_pid, _tuning)
	var o: BugHuntOffer = _mount(popup)
	(o.get_node("%Skip") as Button).pressed.emit()
	assert_true(popup.is_queued_for_deletion())
	assert_false(GameRunner.session.state.projects[_pid].bug_hunt_done)
	assert_eq(GameRunner.session.state.projects[_pid].bugs, 30)


func test_hunt_spawns_and_expires() -> void:
	var parts: Array = _hunt()
	var popup: PopupCard = parts[0]
	var h: BugHuntView = parts[1]
	var card: Rect2 = (popup.get_node("%Card") as Control).get_rect()
	var seen: Dictionary = {}
	var t: float = 0.0
	var max_live: int = 0
	while t < _tuning.bug_hunt_seconds - 0.2:
		h.step(0.1)
		t += 0.1
		max_live = maxi(max_live, h.live_bugs().size())
		for b: TextureButton in h.live_bugs():
			if not seen.has(b):
				seen[b] = t
			var r := Rect2(b.position, b.size)
			assert_true(PLAY.encloses(r), "bug inside play rect %s" % r)
			assert_false(r.intersects(card), "bug clear of card %s" % r)
			assert_lt(t - float(seen[b]), BugHuntView.BUG_LIFETIME_S + 0.001, "bug expires")
	assert_gt(max_live, 0)
	assert_gt(seen.size(), 0)


func test_hunt_total_spawns() -> void:
	var h: BugHuntView = _hunt()[1]
	var t: float = 0.0
	while t < _tuning.bug_hunt_seconds + 0.1:
		h.step(0.05)
		t += 0.05
	assert_eq(h.spawned(), _tuning.bug_hunt_max_bugs + BugHuntView.EXTRA_SPAWNS)
	assert_true(h.is_finished())


func test_catch_counts_and_frees() -> void:
	var h: BugHuntView = _hunt()[1]
	h.step(0.1)
	var bugs: Array[TextureButton] = h.live_bugs()
	assert_eq(bugs.size(), 1)
	bugs[0].pressed.emit()
	assert_eq(h.caught(), 1)
	assert_eq(h.live_bugs().size(), 0)
	assert_string_contains((h.get_node("%Caught") as Label).text, "1")


func test_hunt_finish_submits_capped_result() -> void:
	var h: BugHuntView = _hunt()[1]
	h.step(0.1)
	for i: int in 12:
		h._caught += 1
	h.finish()
	var p: Project = GameRunner.session.state.projects[_pid]
	assert_eq(p.bugs, 20)
	assert_true(p.bug_hunt_done)
	assert_string_contains((h.get_node("%Result") as Label).text, "10")
	assert_true((h.get_node("%Ok") as Button).visible)
	h.finish()
	assert_eq(p.bugs, 20)


func _use_th() -> void:
	Fixtures.use_real_content()
	TranslationServer.set_locale("th")
	GameRunner.start_new_game(1, "Studio")
	var s: GameState = GameRunner.session.state
	_pid = Fixtures.add_project(s, {"phase": Project.Phase.POLISH, "bugs": 30})
	var kind: StringName = &"pevent_bold_idea"
	var def: ProductionEventDef = ContentDB.active().production_events[kind]
	var d := Decision.new()
	d.id = s.alloc_id()
	d.kind = kind
	d.related_ids.assign([_pid])
	d.option_keys.assign(def.option_keys)
	s.pending_decisions.append(d)
	_did = d.id
	_tuning = GameRunner.session.tuning


func _inside_card(popup: PopupCard) -> void:
	var card: Control = popup.get_node("%Card")
	var rect: Rect2 = card.get_global_rect()
	assert_true(Rect2(0, 0, 640, 360).encloses(rect), "card in screen: %s" % rect)
	_check(card, rect)


func _check(node: Node, card_rect: Rect2) -> void:
	for c: Node in node.get_children():
		if c is Control and (c as Control).is_visible_in_tree():
			var ctl: Control = c
			assert_true(card_rect.grow(1.0).encloses(ctl.get_global_rect()), "%s inside card" % ctl.get_path())
			if ctl is Label and (ctl as Label).autowrap_mode == TextServer.AUTOWRAP_OFF and (ctl as Label).text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
				assert_true(ctl.get_minimum_size().x <= ctl.size.x + 1.0, "%s not clipped" % ctl.get_path())
			if ctl is Button:
				assert_true(ctl.get_minimum_size().x <= ctl.size.x + 1.0, "%s button fits" % ctl.get_path())
			_check(ctl, card_rect)


func test_event_popup_fits_th() -> void:
	_use_th()
	var popup: PopupCard = EventView.popup(_did, ContentDB.active())
	var v: EventView = _mount(popup)
	await wait_frames(2)
	_inside_card(popup)
	assert_not_null(v.get_node_or_null("Option_2"), "three options")
	assert_lte((popup.get_node("%Card") as Control).size.y, 231.0, "card height")


func test_offer_fits_th() -> void:
	_use_th()
	var popup: PopupCard = BugHuntOffer.popup(_pid, _tuning)
	_mount(popup)
	await wait_frames(2)
	_inside_card(popup)


func test_bug_hunt_fits_th() -> void:
	_use_th()
	var parts: Array = _hunt()
	var popup: PopupCard = parts[0]
	var h: BugHuntView = parts[1]
	await wait_frames(2)
	_inside_card(popup)
	h.finish()
	await wait_frames(2)
	_inside_card(popup)
