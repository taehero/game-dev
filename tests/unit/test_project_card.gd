extends GutTest

const NAMES: Dictionary[StringName, StringName] = {
	&"topic_fx_space": &"content.topic.space.name",
	&"genre_fx_action": &"content.genre.action.name",
}

var _root: Control


func before_each() -> void:
	TranslationServer.set_locale("en")
	GameRunner.session = GameSession.new(Fixtures.new_state(1), Fixtures.tuning())


func after_each() -> void:
	GameRunner.session = null
	TranslationServer.set_locale("en")


func _card() -> ProjectCard:
	_root = Control.new()
	_root.size = Vector2(640, 360)
	add_child_autofree(_root)
	var card: ProjectCard = load("res://src/ui/hud/project_card.tscn").instantiate()
	_root.add_child(card)
	card.position = Vector2(6, 36)
	card.configure(NAMES)
	return card


func _st() -> GameState:
	return GameRunner.session.state


func _moon() -> void:
	var pid: int = Fixtures.add_project(_st(), {
		"title": "Moon Rally", "phase": Project.Phase.PRODUCTION, "stage_index": 1,
		"stage_progress": 6200, "bugs": 7,
	})
	var p: Project = _st().projects[pid]
	p.points[&"design"] = 42
	p.points[&"tech"] = 31
	p.points[&"art"] = 18
	p.points[&"audio"] = 9


func _refresh(card: ProjectCard) -> void:
	card.refresh(_st())


func test_no_project_shows_chip() -> void:
	var card: ProjectCard = _card()
	_refresh(card)
	assert_false(card.get_node("%Card").visible)
	assert_true(card.get_node("%Chip").visible)
	assert_eq(card.get_node("%ChipText").text, tr("ui.status.no_project"))


func test_card_shows_title_subtitle_stage_and_tiles() -> void:
	_moon()
	var card: ProjectCard = _card()
	_refresh(card)
	assert_true(card.get_node("%Card").visible)
	assert_false(card.get_node("%Chip").visible)
	assert_eq(card.get_node("%Title").text, "Moon Rally")
	assert_eq(card.get_node("%Subtitle").text, tr("ui.card.subtitle").format({"topic": tr("content.topic.space.name"), "genre": tr("content.genre.action.name")}))
	assert_eq(card.get_node("%Stage").text, tr("ui.status.stage").format({"stage": 2, "count": 3, "progress": 62}))
	assert_eq(card.tile_number(&"design").text, "42")
	assert_eq(card.tile_number(&"tech").text, "31")
	assert_eq(card.tile_number(&"art").text, "18")
	assert_eq(card.tile_number(&"audio").text, "9")
	assert_eq(card.tile_number(&"bug").text, "7")


func test_stage_bar_segments() -> void:
	_moon()
	var card: ProjectCard = _card()
	_refresh(card)
	var bar: StageBar = card.get_node("%StageBar")
	assert_eq(bar.segment_count(), 3)
	assert_eq(bar.segment_fill(0), 100)
	assert_eq(bar.segment_fill(1), 62)
	assert_eq(bar.segment_fill(2), 0)
	assert_eq(bar.segment_color(0), UiPalette.SUCCESS)
	assert_eq(bar.segment_color(1), UiPalette.ACCENT)
	assert_eq(bar.segment_color(2), UiPalette.TRACK)


func test_stage_bar_clamps() -> void:
	var bar := StageBar.new()
	add_child_autofree(bar)
	bar.set_stages(3, 9, 150)
	assert_eq(bar.segment_fill(2), 100)
	bar.set_stages(0, 1, 50)
	assert_eq(bar.segment_count(), 1)


func test_unknown_names_and_single_stage() -> void:
	Fixtures.add_project(_st(), {"kind": Project.Kind.ENGINE, "phase": Project.Phase.PRODUCTION})
	var pid: int = StateQueries.active_project_id(_st())
	_st().projects[pid].config[&"topic"] = &"topic_nope"
	var card: ProjectCard = _card()
	_refresh(card)
	assert_eq(card.get_node("%Subtitle").text, tr("content.genre.action.name"))
	assert_eq((card.get_node("%StageBar") as StageBar).segment_count(), 1)


func test_tile_colours_follow_point_colours() -> void:
	_moon()
	var card: ProjectCard = _card()
	_refresh(card)
	var box: StyleBoxFlat = card.get_node("%Card").find_child("Tile_tech", true, false).get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(box.bg_color, UiPalette.tint(UiPalette.POINT_COLORS[&"tech"]))
	assert_eq(card.tile_number(&"tech").get_theme_color(&"font_color"), UiPalette.ink(UiPalette.POINT_COLORS[&"tech"]))


func test_card_refreshes_on_game_loaded() -> void:
	var card: ProjectCard = _card()
	var fresh: GameState = Fixtures.new_state(2)
	Fixtures.add_project(fresh, {"title": "Loaded"})
	GameRunner.session = GameSession.new(fresh, Fixtures.tuning())
	EventBus.dispatch(&"game_loaded", {})
	assert_eq(card.get_node("%Title").text, "Loaded")


func _assert_fits(locale: String) -> void:
	TranslationServer.set_locale(locale)
	var pid: int = Fixtures.add_project(_st(), {
		"title": "X".repeat(200), "phase": Project.Phase.PRODUCTION, "stage_index": 2,
		"stage_progress": 9900, "bugs": 9999,
	})
	for k: StringName in [&"design", &"tech", &"art", &"audio"]:
		_st().projects[pid].points[k] = 9999
	var card: ProjectCard = _card()
	_refresh(card)
	await get_tree().process_frame
	await get_tree().process_frame
	var labels: Array[Label] = []
	for kind: StringName in ProjectCard.TILE_KINDS:
		var tile: Node = card.find_child("Tile_" + String(kind), true, false)
		labels.append(tile.find_child("Number", true, false))
		labels.append(tile.find_child("Name", true, false))
	labels.append(card.get_node("%Stage"))
	if locale == "th":
		labels.append(card.get_node("%Subtitle"))
	for l: Label in labels:
		assert_true(UiFit.text_fits(l), "%s %s '%s'" % [locale, l.get_path(), l.text])
	assert_eq((card.get_node("%Title") as Label).text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)
	assert_eq(card.get_node("%Card").size.x, 210.0)
	assert_true(UiFit.inside_screen(card.get_node("%Card")))


func test_card_fits_worst_case_en() -> void:
	await _assert_fits("en")


func test_card_fits_worst_case_th() -> void:
	await _assert_fits("th")
