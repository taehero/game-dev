class_name TopBar
extends HBoxContainer
## Resource pills and speed control. Reads through StateQueries; speed via GameRunner.set_speed.

const PILL_WIDTHS: Dictionary[StringName, int] = {&"date": 148, &"money": 108, &"fans": 104, &"hype": 76}
const EVENT_SIGNALS: Array[StringName] = [
	&"week_ticked", &"money_changed", &"project_changed", &"project_phase_changed",
	&"sales_updated", &"review_published", &"game_loaded",
]


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_setup_pills()
	for sig_name: StringName in EVENT_SIGNALS:
		var sig: Signal = Signal(EventBus, sig_name)
		sig.connect(_on_event)
	_on_event({})


func _exit_tree() -> void:
	for sig_name: StringName in EVENT_SIGNALS:
		var sig: Signal = Signal(EventBus, sig_name)
		if sig.is_connected(_on_event):
			sig.disconnect(_on_event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_setup_pills()
		_on_event({})


func _setup_pills() -> void:
	(%Date as ResourcePill).setup(&"date", "", UiPalette.DATE, &"PillLabel", &"ui.pill.date", PILL_WIDTHS[&"date"])
	(%Money as ResourcePill).setup(&"", tr("ui.pill.currency"), UiPalette.MONEY, &"NumberLarge",
		&"ui.pill.money", PILL_WIDTHS[&"money"])
	(%Fans as ResourcePill).setup(&"fans", "", UiPalette.FANS, &"NumberLarge", &"ui.pill.fans", PILL_WIDTHS[&"fans"])
	(%Hype as ResourcePill).setup(&"hype", "", UiPalette.HYPE, &"NumberLarge", &"ui.pill.hype", PILL_WIDTHS[&"hype"])


func refresh(view: GameState, t: TuningDef) -> void:
	var info: Dictionary = StateQueries.resource_view(view, t)
	(%Date as ResourcePill).set_value(info["date_text"])
	(%Money as ResourcePill).set_value(UiFormat.thousands(info["money"]))
	(%Fans as ResourcePill).set_value(UiFormat.thousands(info["fans"]))
	(%Hype as ResourcePill).set_value(UiFormat.thousands(info["hype"]))


func _on_event(_payload: Dictionary) -> void:
	if GameRunner.session == null:
		return
	refresh(GameRunner.session.state, GameRunner.session.tuning)
	(%Speed as SpeedControl).sync(GameRunner.session.speed)
