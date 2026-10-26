extends GutTest

var _saved_locale: String


func before_each() -> void:
	ContentDB.use(Fixtures.content())
	_saved_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	GameRunner.session = GameSession.new(Fixtures.new_state(1), Fixtures.tuning())


func after_each() -> void:
	GameRunner.session = null
	TranslationServer.set_locale(_saved_locale)
	ContentDB.use(Fixtures.content())


func _mount(is_engine: bool = false) -> Array:
	var screen := Control.new()
	screen.size = Vector2(640, 360)
	add_child_autofree(screen)
	var popup: PopupCard
	if is_engine:
		popup = EnginePopup.popup(ContentDB.active())
	else:
		popup = ConceptWizard.popup(ContentDB.active())
	screen.add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return [popup, popup.body().get_child(0)]


func _set_title(w: Node, text: String) -> void:
	var edit: LineEdit = w.get_node("%TitleEdit")
	edit.text = text
	edit.text_changed.emit(text)


func _row(w: Node, path: String) -> ChoiceRow:
	return w.get_node(path) as ChoiceRow


func _step0(w: ConceptWizard) -> void:
	_set_title(w, "Moon")
	_row(w, "%Sizes").select(&"size_small")
	_row(w, "%Platforms").select(&"platform_fx_micro")


func _step1(w: ConceptWizard) -> void:
	_row(w, "%Topics").select(&"topic_fx_space")
	_row(w, "%Genres").select(&"genre_fx_action")


func _game_projects() -> Array[Project]:
	var out: Array[Project] = []
	var view: GameState = GameRunner.session.state
	for pid: int in view.sorted_ids(view.projects):
		if view.projects[pid].kind == Project.Kind.GAME:
			out.append(view.projects[pid])
	return out


func test_three_steps_create_game() -> void:
	var parts: Array = _mount()
	var popup: PopupCard = parts[0]
	var w: ConceptWizard = parts[1]
	await wait_frames(1)
	assert_eq(w.step(), 0)
	_step0(w)
	w.next()
	assert_eq(w.step(), 1)
	_step1(w)
	assert_string_contains((w.get_node("%Combo") as Label).text, tr("ui.combo.unknown"))
	w.next()
	assert_eq(w.step(), 2)
	_row(w, "%Engines").select(&"lic_engine_homebrew")
	assert_true(w.create())
	var made: Array[Project] = _game_projects()
	assert_eq(made.size(), 1)
	assert_eq(made[0].title, "Moon")
	assert_eq(made[0].size_id, &"size_small")
	assert_eq(made[0].config[&"platform"], &"platform_fx_micro")
	assert_eq(made[0].config[&"topic"], &"topic_fx_space")
	assert_eq(made[0].config[&"genre"], &"genre_fx_action")
	assert_eq(made[0].config[&"engine"], &"lic_engine_homebrew")
	assert_true(popup.is_queued_for_deletion())


func test_next_disabled_until_choices() -> void:
	var w: ConceptWizard = _mount()[1]
	await wait_frames(1)
	var next_btn: Button = w.get_node("%Next")
	assert_eq((w.get_node("%TitleEdit") as LineEdit).text, tr("ui.wizard.default_title"))
	assert_true(next_btn.disabled)
	_row(w, "%Sizes").select(&"size_small")
	assert_true(next_btn.disabled)
	_row(w, "%Platforms").select(&"platform_fx_micro")
	assert_false(next_btn.disabled)
	_set_title(w, "   ")
	assert_true(next_btn.disabled)
	_set_title(w, "Moon")
	assert_false(next_btn.disabled)
	w.next()
	assert_true(next_btn.disabled)
	_row(w, "%Topics").select(&"topic_fx_space")
	assert_true(next_btn.disabled)
	_row(w, "%Genres").select(&"genre_fx_action")
	assert_false(next_btn.disabled)
	w.next()
	assert_false((w.get_node("%Create") as Button).visible == false)
	assert_false(next_btn.visible)


func test_back_keeps_choices() -> void:
	var w: ConceptWizard = _mount()[1]
	await wait_frames(1)
	_step0(w)
	w.next()
	_step1(w)
	w.back()
	assert_eq(w.step(), 0)
	assert_eq(_row(w, "%Sizes").selected(), &"size_small")
	assert_eq(_row(w, "%Platforms").selected(), &"platform_fx_micro")
	assert_eq((w.get_node("%TitleEdit") as LineEdit).text, "Moon")
	w.next()
	assert_eq(_row(w, "%Topics").selected(), &"topic_fx_space")
	assert_eq(_row(w, "%Genres").selected(), &"genre_fx_action")
	w.back()
	w.back()
	assert_eq(w.step(), 0)


func test_refused_create_shows_reason_and_stays_open() -> void:
	var view: GameState = GameRunner.session.state
	var first := StartProjectCommand.game(view.player_company_id, "Busy", &"size_small", &"platform_fx_micro", &"topic_fx_space", &"genre_fx_action", -1, &"lic_engine_homebrew", [] as Array[StringName])
	assert_true(GameRunner.submit(first).ok)
	var parts: Array = _mount()
	var popup: PopupCard = parts[0]
	var w: ConceptWizard = parts[1]
	await wait_frames(1)
	_step0(w)
	w.next()
	_step1(w)
	w.next()
	_row(w, "%Engines").select(&"lic_engine_homebrew")
	assert_false(w.create())
	assert_eq((w.get_node("%Status") as Label).text, tr("error.not_enough_staff"))
	assert_false(popup.is_queued_for_deletion())
	assert_eq(_game_projects().size(), 1)


func test_only_kit_platforms_listed() -> void:
	GameRunner.session.state.week = 30
	var w: ConceptWizard = _mount()[1]
	await wait_frames(1)
	assert_not_null(w.get_node_or_null("%Platforms/Choice_platform_fx_micro"))
	assert_null(w.get_node_or_null("%Platforms/Choice_platform_fx_console"))
	assert_true((w.get_node("%MorePlatforms") as Control).visible)


func test_more_platforms_hidden_without_kitless() -> void:
	var w: ConceptWizard = _mount()[1]
	await wait_frames(1)
	assert_false((w.get_node("%MorePlatforms") as Control).visible)


func test_features_follow_engine() -> void:
	var view: GameState = GameRunner.session.state
	view.companies[view.player_company_id].unlocked.append(&"research_fx_scroll")
	var eid: int = Fixtures.add_engine(view, {"features": [&"feature_fx_scroll"], "name": "Mine"})
	var w: ConceptWizard = _mount()[1]
	await wait_frames(1)
	_step0(w)
	w.next()
	_step1(w)
	w.next()
	var feats: ChoiceRow = _row(w, "%Features")
	_row(w, "%Engines").select(&"lic_engine_homebrew")
	assert_not_null(feats.get_node_or_null("Choice_feature_fx_save"))
	assert_null(feats.get_node_or_null("Choice_feature_fx_scroll"))
	var built: StringName = StringName("built_%d" % eid)
	_row(w, "%Engines").select(built)
	assert_not_null(feats.get_node_or_null("Choice_feature_fx_scroll"))
	assert_null(feats.get_node_or_null("Choice_feature_fx_save"))
	feats.select(&"feature_fx_scroll")
	_row(w, "%Engines").select(&"lic_engine_homebrew")
	assert_true(feats.selected_many().is_empty(), "unsupported selection dropped")
	assert_false((w.get_node("%NoFeatures") as Control).visible)
	_row(w, "%Engines").select(built)
	feats.select(&"feature_fx_scroll")
	assert_true(w.create())
	var p: Project = _game_projects()[0]
	assert_eq(p.engine_id, eid)
	assert_eq(p.features, [&"feature_fx_scroll"] as Array[StringName])


func test_engine_popup_builds_engine() -> void:
	var parts: Array = _mount(true)
	var popup: PopupCard = parts[0]
	var w: EnginePopup = parts[1]
	await wait_frames(1)
	var create_btn: Button = w.get_node("%Create")
	assert_eq((w.get_node("%TitleEdit") as LineEdit).text, tr("ui.engine.default_title"))
	assert_true(create_btn.disabled)
	(w.get_node("%Features") as ChoiceRow).select(&"feature_fx_save")
	assert_false(create_btn.disabled)
	_set_title(w, "")
	assert_true(create_btn.disabled)
	_set_title(w, "Core")
	assert_false(create_btn.disabled)
	assert_true(w.create())
	var found: Array[Project] = []
	var view: GameState = GameRunner.session.state
	for pid: int in view.sorted_ids(view.projects):
		if view.projects[pid].kind == Project.Kind.ENGINE:
			found.append(view.projects[pid])
	assert_eq(found.size(), 1)
	assert_eq(found[0].features, [&"feature_fx_save"] as Array[StringName])
	assert_true(popup.is_queued_for_deletion())


func test_engine_popup_hint_when_no_features_researched() -> void:
	var parts: Array = _mount(true)
	assert_null(parts[1].get_node_or_null("%NoFeatures"), "free feature present: no hint")
	var screen := Control.new()
	screen.size = Vector2(640, 360)
	add_child_autofree(screen)
	var popup: PopupCard = EnginePopup.popup(ContentDB.new())
	screen.add_child(popup)
	await wait_frames(1)
	var bare: Node = popup.body().get_child(0)
	assert_eq((bare.get_node("%NoFeatures") as Label).text, tr("ui.engine.no_features"))
	assert_true((bare.get_node("%Create") as Button).disabled)


func test_engine_create_is_gated_by_command_validation() -> void:
	var w: EnginePopup = _mount(true)[1]
	await wait_frames(1)
	(w.get_node("%Features") as ChoiceRow).select(&"feature_fx_save")
	var create_btn: Button = w.get_node("%Create")
	assert_false(create_btn.disabled)
	assert_eq(create_btn.tooltip_text, "")
	for sid: int in GameRunner.session.state.staff_of(GameRunner.session.state.player_company_id):
		GameRunner.session.state.staff[sid].assigned_project_id = 999
	_set_title(w, "Core")
	assert_true(create_btn.disabled, "validate refuses without free staff")
	assert_eq(create_btn.tooltip_text, tr("error.not_enough_staff"))


func test_engine_popup_feature_label_has_weeks() -> void:
	var w: EnginePopup = _mount(true)[1]
	await wait_frames(1)
	var btn: Button = w.get_node("%Features/Choice_feature_fx_save")
	assert_string_contains(btn.text, " · ")
	assert_string_contains(btn.text, tr("ui.engine.weeks").format({"weeks": 2}))


func _inside_card(popup: PopupCard) -> void:
	var card: Control = popup.get_node("%Card")
	var rect: Rect2 = card.get_global_rect()
	assert_true(Rect2(0, 0, 640, 360).encloses(rect), "card in screen: %s" % rect)
	_check_controls(card, rect)


func _check_controls(node: Node, card_rect: Rect2) -> void:
	for c: Node in node.get_children():
		if c is Control and (c as Control).is_visible_in_tree():
			var ctl: Control = c
			assert_true(card_rect.grow(1.0).encloses(ctl.get_global_rect()), "%s inside card" % ctl.get_path())
			if ctl is Label and (ctl as Label).autowrap_mode == TextServer.AUTOWRAP_OFF and (ctl as Label).text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
				assert_true(ctl.get_minimum_size().x <= ctl.size.x + 1.0, "%s not clipped" % ctl.get_path())
			if ctl is Button:
				assert_true(ctl.get_minimum_size().x <= ctl.size.x + 1.0, "%s button not clipped" % ctl.get_path())
		_check_controls(c, card_rect)


func _pick_first(row: ChoiceRow) -> void:
	if row.get_child_count() > 0:
		(row.get_child(0) as Button).button_pressed = true


func _use_real_th() -> void:
	Fixtures.use_real_content()
	TranslationServer.set_locale("th")
	GameRunner.start_new_game(1, "Studio")
	var view: GameState = GameRunner.session.state
	Fixtures.add_engine(view, {"name": "เอนจินทดสอบยาวมากพอสมควร", "features": [] as Array[StringName]})


func test_wizard_fits_th() -> void:
	_use_real_th()
	var parts: Array = _mount()
	var popup: PopupCard = parts[0]
	var w: ConceptWizard = parts[1]
	await wait_frames(2)
	_inside_card(popup)
	for n: String in ["%Sizes", "%Platforms"]:
		_pick_first(_row(w, n))
	_set_title(w, "ชื่อเกมภาษาไทยที่ยาวมากมายก่ายกอง")
	w.next()
	await wait_frames(2)
	_inside_card(popup)
	for n: String in ["%Topics", "%Genres"]:
		_pick_first(_row(w, n))
	await wait_frames(2)
	_inside_card(popup)
	w.next()
	await wait_frames(2)
	_pick_first(_row(w, "%Engines"))
	await wait_frames(2)
	_inside_card(popup)
	assert_eq(w.step(), 2)


func test_engine_popup_fits_th() -> void:
	_use_real_th()
	var parts: Array = _mount(true)
	var popup: PopupCard = parts[0]
	await wait_frames(2)
	_inside_card(popup)
