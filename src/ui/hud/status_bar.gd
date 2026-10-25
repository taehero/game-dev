class_name StatusBar
extends PanelContainer
## Bottom status bar: active project on the left, date, money and speed on the right.
## Reads state only through StateQueries and re-reads GameRunner.session on every event.

const BAR_HEIGHT: int = 22
const TITLE_MIN_WIDTH: int = 60
const DATE_MIN_WIDTH: int = 104
const MONEY_MIN_WIDTH: int = 80

const EVENT_SIGNALS: Array[StringName] = [
	&"week_ticked", &"money_changed", &"project_changed", &"project_phase_changed", &"game_loaded",
]


func _ready() -> void:
	custom_minimum_size.y = BAR_HEIGHT
	for node_name: String in ["Title", "Points", "Date", "Money"]:
		var label: Label = get_node("%" + node_name)
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var title: Label = %Title
	title.custom_minimum_size.x = TITLE_MIN_WIDTH
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	%Points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	%Date.custom_minimum_size.x = DATE_MIN_WIDTH
	%Money.custom_minimum_size.x = MONEY_MIN_WIDTH
	_translate_buttons()
	%Pause.pressed.connect(_on_speed.bind(0))
	%Speed1x.pressed.connect(_on_speed.bind(1))
	%Speed2x.pressed.connect(_on_speed.bind(2))
	%Speed4x.pressed.connect(_on_speed.bind(4))
	for sig_name: StringName in EVENT_SIGNALS:
		var sig: Signal = Signal(EventBus, sig_name)
		sig.connect(_on_event)
	_on_event({})


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_translate_buttons()
		if GameRunner.session != null:
			refresh(GameRunner.session.state, GameRunner.session.tuning)


func _translate_buttons() -> void:
	%Pause.text = tr("ui.hud.pause")
	%Speed1x.text = tr("ui.hud.speed").format({"speed": 1})
	%Speed2x.text = tr("ui.hud.speed").format({"speed": 2})
	%Speed4x.text = tr("ui.hud.speed").format({"speed": 4})


func _exit_tree() -> void:
	for sig_name: StringName in EVENT_SIGNALS:
		var sig: Signal = Signal(EventBus, sig_name)
		if sig.is_connected(_on_event):
			sig.disconnect(_on_event)


func refresh(view: GameState, t: TuningDef) -> void:
	%Date.text = StateQueries.date_text(view, t)
	%Money.text = tr("ui.hud.money").format({"money": StateQueries.player_money(view)})
	var pid: int = StateQueries.active_project_id(view)
	var info: Dictionary = StateQueries.project_status(view, pid)
	var has_project: bool = not info.is_empty()
	for node_name: String in ["Stage", "Points", "Bugs", "Hype"]:
		(get_node("%" + node_name) as Label).visible = has_project
	if not has_project:
		%Title.text = tr("ui.status.no_project")
		return
	%Title.text = String(info["title"])
	%Stage.text = tr("ui.status.stage").format({
		"stage": info["stage"], "count": GameRules.stage_count(view.projects[pid]), "progress": info["progress"],
	})
	%Points.text = tr("ui.status.points").format({
		"design": info["design"], "tech": info["tech"], "art": info["art"], "audio": info["audio"],
	})
	%Bugs.text = tr("ui.status.bugs").format({"bugs": info["bugs"]})
	%Hype.text = tr("ui.status.hype").format({"hype": info["hype"]})


func _on_event(_payload: Dictionary) -> void:
	if GameRunner.session == null:
		return
	refresh(GameRunner.session.state, GameRunner.session.tuning)


func _on_speed(s: int) -> void:
	GameRunner.set_speed(s)
