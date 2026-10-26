class_name PanelBase
extends ScrollContainer
## Shared base for the dock panels: refresh on game events, submit with a status line, gate buttons.

const EVENT_SIGNALS: Array[StringName] = [&"week_ticked", &"money_changed", &"project_changed",
	&"project_phase_changed", &"sales_updated", &"review_published", &"research_done",
	&"staff_hired", &"game_loaded", &"decision_required"]

var content: ContentDB

var _body: VBoxContainer
var _status: Label


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := VBoxContainer.new()
	column.name = "Column"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(column)
	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body)
	_status = Label.new()
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override(&"font_color", UiPalette.DANGER)
	_status.unique_name_in_owner = true
	column.add_child(_status)
	_status.owner = self


func _ready() -> void:
	for sig: StringName in EVENT_SIGNALS:
		if not EventBus.is_connected(sig, _on_event):
			EventBus.connect(sig, _on_event)
	visibility_changed.connect(_on_visibility_changed)
	_refresh_now()


func _exit_tree() -> void:
	for sig: StringName in EVENT_SIGNALS:
		if EventBus.is_connected(sig, _on_event):
			EventBus.disconnect(sig, _on_event)


func configure(p_content: ContentDB) -> void:
	content = p_content
	_refresh_now()


func body() -> VBoxContainer:
	return _body


func status_label() -> Label:
	return _status


## Virtual: rebuild the panel from the read-only view.
func refresh(_view: GameState, _t: TuningDef) -> void:
	pass


func submit(cmd: Command) -> bool:
	var result: CommandResult = GameRunner.submit(cmd)
	_status.text = "" if result.ok else tr(result.reason_key)
	if result.ok:
		_refresh_now()
	return result.ok


func gate(button: BaseButton, cmd: Command) -> void:
	var session: GameSession = GameRunner.session
	if session == null:
		return
	var result: CommandResult = cmd.validate(session.state, session.tuning)
	button.disabled = not result.ok
	button.tooltip_text = "" if result.ok else tr(result.reason_key)


func _refresh_now() -> void:
	if GameRunner.session != null and is_inside_tree():
		refresh(GameRunner.session.state, GameRunner.session.tuning)


func _on_event(_payload: Dictionary) -> void:
	_refresh_now()


func _on_visibility_changed() -> void:
	if visible:
		_refresh_now()
