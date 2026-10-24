extends Control
## Debug HUD: reads state via StateQueries, acts only through GameRunner.

const SAVE_SLOT: String = "slot_1"
const DEBUG_HIRE_SALARY: int = 800
## Plain names (data, not display text).
const DEBUG_NAMES: Array[String] = ["Ada", "Bo", "Cy", "Di", "Eli", "Fay", "Gus", "Hal"]

var _hire_index: int = 0

@onready var _date: Label = %DateLabel
@onready var _money: Label = %MoneyLabel
@onready var _staff: Label = %StaffLabel
@onready var _message: Label = %MessageLabel


func _ready() -> void:
	%Pause.text = tr("ui.hud.pause")
	%Speed1x.text = tr("ui.hud.speed").format({"speed": 1})
	%Speed2x.text = tr("ui.hud.speed").format({"speed": 2})
	%Speed4x.text = tr("ui.hud.speed").format({"speed": 4})
	%Hire.text = tr("ui.hud.hire")
	%Save.text = tr("ui.hud.save")
	%Load.text = tr("ui.hud.load")
	%Pause.pressed.connect(_on_speed.bind(0))
	%Speed1x.pressed.connect(_on_speed.bind(1))
	%Speed2x.pressed.connect(_on_speed.bind(2))
	%Speed4x.pressed.connect(_on_speed.bind(4))
	%Hire.pressed.connect(_on_hire)
	%Save.pressed.connect(_on_save)
	%Load.pressed.connect(_on_load)
	EventBus.week_ticked.connect(_on_refresh_event)
	EventBus.money_changed.connect(_on_refresh_event)
	EventBus.staff_hired.connect(_on_refresh_event)
	EventBus.command_rejected.connect(_on_command_rejected)
	_refresh()


func _exit_tree() -> void:
	for sig: Signal in [EventBus.week_ticked, EventBus.money_changed, EventBus.staff_hired]:
		if sig.is_connected(_on_refresh_event):
			sig.disconnect(_on_refresh_event)
	if EventBus.command_rejected.is_connected(_on_command_rejected):
		EventBus.command_rejected.disconnect(_on_command_rejected)


func _refresh() -> void:
	if GameRunner.session == null:
		return
	var st: GameState = GameRunner.session.state
	_date.text = StateQueries.date_text(st, GameRunner.session.tuning)
	_money.text = tr("ui.hud.money").format({"money": StateQueries.player_money(st)})
	_staff.text = tr("ui.hud.staff").format({"count": StateQueries.staff_count(st, StateQueries.player_company_id(st))})


func _on_refresh_event(_payload: Dictionary) -> void:
	_refresh()


func _on_command_rejected(payload: Dictionary) -> void:
	_message.text = tr(String(payload.get("reason_key", "")))


func _on_speed(s: int) -> void:
	GameRunner.set_speed(s)


func _on_hire() -> void:
	var st: GameState = GameRunner.session.state
	var hire_name: String = DEBUG_NAMES[_hire_index % DEBUG_NAMES.size()]
	_hire_index += 1
	GameRunner.submit(HireStaffCommand.new(StateQueries.player_company_id(st), hire_name, DEBUG_HIRE_SALARY))
	_refresh()


func _on_save() -> void:
	var err: Error = GameRunner.save_game(SAVE_SLOT)
	_message.text = ""
	if err != OK:
		push_warning("DebugHud: save failed (%d)" % err)


func _on_load() -> void:
	var r: LoadResult = GameRunner.load_game(SAVE_SLOT)
	if r.ok:
		_message.text = ""
		_refresh()
	else:
		_message.text = tr(String(r.error_key))
