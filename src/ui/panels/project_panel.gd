class_name ProjectPanel
extends PanelBase
## Project tab: the active project's phase and focus sliders, release / bug hunt, and past games.

signal new_game_requested
signal new_engine_requested
signal bug_hunt_requested(project_id: int)
signal details_requested(project_id: int)

const SLIDER_KEYS: Array[Array] = [
	[&"ui.slider.code", &"ui.slider.design", &"ui.slider.story"],
	[&"ui.slider.levels", &"ui.slider.characters", &"ui.slider.ai"],
	[&"ui.slider.graphics", &"ui.slider.audio", &"ui.slider.balance"],
]
const PHASE_KEYS: Dictionary[int, StringName] = {
	Project.Phase.PRODUCTION: &"ui.phase.production",
	Project.Phase.POLISH: &"ui.phase.polish",
	Project.Phase.RELEASED: &"ui.phase.released",
	Project.Phase.LIVE: &"ui.phase.live",
	Project.Phase.RETIRED: &"ui.phase.retired",
}

var _top: VBoxContainer
var _past: VBoxContainer
var _built_key: Array = []
var _past_built: Array[Dictionary] = []
var _past_dirty: bool = true
var _synced: Array = [[], [], []]


func _init() -> void:
	super()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top = VBoxContainer.new()
	_top.name = "Top"
	_body.add_child(_top)
	_past = VBoxContainer.new()
	_past.name = "PastGames"
	_past.unique_name_in_owner = true
	_body.add_child(_past)
	_past.owner = self


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_built_key = []
		_past_dirty = true
		_refresh_now()


func refresh(view: GameState, _t: TuningDef) -> void:
	var pid: int = StateQueries.active_project_id(view)
	var detail: Dictionary = StateQueries.project_detail(view, pid)
	var key: Array = [pid, int(detail.get("phase", -1))]
	if key != _built_key:
		_built_key = key
		_build_top(detail)
	if not detail.is_empty():
		_update_top(detail)
	_refresh_past(StateQueries.past_games(view))


func _clear(box: Control) -> void:
	for c: Node in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _add_unique(parent: Node, node: Control, node_name: String) -> void:
	node.name = node_name
	node.unique_name_in_owner = true
	parent.add_child(node)
	node.owner = self


func _label(text: String, variation: StringName = &"") -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	return l


func _ellipsis(l: Label) -> Label:
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	if primary:
		b.theme_type_variation = &"PrimaryButton"
	return b


func _build_top(detail: Dictionary) -> void:
	_clear(_top)
	_synced = [[], [], []]
	if detail.is_empty():
		_add_unique(_top, _label(tr("ui.project.none")), "None")
		var new_game: Button = _button(tr("ui.project.new_game"), true)
		new_game.pressed.connect(func() -> void: new_game_requested.emit())
		_add_unique(_top, new_game, "NewGame")
		var new_engine: Button = _button(tr("ui.project.new_engine"), false)
		new_engine.pressed.connect(func() -> void: new_engine_requested.emit())
		_add_unique(_top, new_engine, "NewEngine")
		return
	var pid: int = detail["id"]
	_add_unique(_top, _ellipsis(_label("", &"CardTitle")), "Title")
	_add_unique(_top, _label(""), "Phase")
	if detail["kind"] == Project.Kind.ENGINE:
		_add_unique(_top, _label(tr("ui.project.engine_building")), "EngineBuilding")
		return
	_add_unique(_top, _label(tr("ui.project.focus"), &"SectionLabel"), "Focus")
	for s: int in 3:
		_top.add_child(_label(tr("ui.project.stage_name").format({"n": s + 1}), &"SectionLabel"))
		var triple := SliderTriple.new()
		_add_unique(_top, triple, "Stage_%d" % s)
		triple.values_committed.connect(_on_values_committed.bind(pid, s))
	var release: Button = _button(tr("ui.project.release"), true)
	release.pressed.connect(func() -> void: submit(ReleaseProjectCommand.new(pid)))
	_add_unique(_top, release, "Release")
	var hunt: Button = _button(tr("ui.project.bug_hunt"), false)
	hunt.pressed.connect(func() -> void: bug_hunt_requested.emit(pid))
	_add_unique(_top, hunt, "BugHunt")


func _update_top(detail: Dictionary) -> void:
	var pid: int = detail["id"]
	(get_node("%Title") as Label).text = String(detail["title"])
	var phase_text: String = tr(PHASE_KEYS.get(detail["phase"], &"ui.phase.production"))
	if detail["phase"] == Project.Phase.PRODUCTION:
		phase_text += " · " + tr("ui.status.stage").format({
			"stage": detail["stage"], "count": detail["stage_count"], "progress": detail["progress"],
		})
	(get_node("%Phase") as Label).text = phase_text
	if detail["kind"] == Project.Kind.ENGINE:
		return
	var focus: Array[int] = detail["focus"]
	for s: int in 3:
		var triple: SliderTriple = get_node("%%Stage_%d" % s) as SliderTriple
		var mine: Array = focus.slice(s * 3, s * 3 + 3)
		if mine != _synced[s]:
			_synced[s] = mine
			var typed: Array[int] = []
			typed.assign(mine)
			triple.setup(_label_keys(s), typed)
		triple.set_editable(detail["can_edit_sliders"] and s >= detail["stage_index"])
	var release: Button = get_node("%Release") as Button
	release.visible = detail["can_release"]
	gate(release, ReleaseProjectCommand.new(pid))
	var hunt: Button = get_node("%BugHunt") as Button
	hunt.visible = detail["can_bug_hunt"]
	gate(hunt, SubmitBugHuntCommand.new(pid, 0))


func _label_keys(stage: int) -> Array[StringName]:
	var keys: Array[StringName] = []
	keys.assign(SLIDER_KEYS[stage])
	return keys


func _on_values_committed(_values: Array[int], pid: int, stage: int) -> void:
	var session: GameSession = GameRunner.session
	var detail: Dictionary = StateQueries.project_detail(session.state, pid)
	var focus: Array[int] = []
	if not detail.is_empty():
		focus.assign(detail["focus"])
	var triple: SliderTriple = get_node("%%Stage_%d" % stage) as SliderTriple
	var mine: Array[int] = triple.values()
	for i: int in 3:
		if focus.size() == 9:
			focus[stage * 3 + i] = mine[i]
	if focus.size() != 9 or not submit(SetSlidersCommand.new(pid, focus)):
		_built_key = []
		_synced = [[], [], []]
		_refresh_now()


func _refresh_past(games: Array[Dictionary]) -> void:
	if not _past_dirty and games == _past_built:
		return
	_past_dirty = false
	_past_built = games
	_clear(_past)
	_past.add_child(_label(tr("ui.project.past_games"), &"SectionLabel"))
	if games.is_empty():
		_add_unique(_past, _label(tr("ui.project.no_past_games")), "NoPastGames")
		return
	for g: Dictionary in games:
		_past.add_child(_past_row(g))


func _past_row(g: Dictionary) -> Control:
	var id: int = g["id"]
	var row := PanelContainer.new()
	row.name = "Game_%d" % id
	row.theme_type_variation = &"RowPanel"
	var col := VBoxContainer.new()
	row.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	head.add_child(_ellipsis(_label(String(g["title"]))))
	var details: Button = _button(tr("ui.project.details"), false)
	details.name = "Details"
	details.pressed.connect(func() -> void: details_requested.emit(id))
	head.add_child(details)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override(&"separation", 10)
	col.add_child(stats)
	stats.add_child(_label(tr(PHASE_KEYS.get(g["phase"], &"ui.phase.released")), &"SectionLabel"))
	stats.add_child(_label(UiFormat.score(g["user_score"])))
	stats.add_child(_label(tr("ui.project.units").format({"units": UiFormat.thousands(g["units_sold"])})))
	stats.add_child(_label(UiFormat.money(g["revenue"])))
	return row
