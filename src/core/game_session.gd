class_name GameSession
extends RefCounted
## Real-time clock over a GameState. Floats here are pacing only, never state.

const VALID_SPEEDS: Array[int] = [0, 1, 2, 4]

var state: GameState
var tuning: TuningDef
var speed: int = 0
## Speed a decision auto-pause interrupted; 0 when none. Cleared by any set_speed.
var auto_paused_speed: int = 0
var autosave_due: bool = false

var _accumulator: float = 0.0
var _queue: Array[Command] = []
var _events: Array[Dictionary] = []


func _init(p_state: GameState, p_tuning: TuningDef) -> void:
	state = p_state
	tuning = p_tuning


func set_speed(s: int) -> void:
	if not VALID_SPEEDS.has(s):
		push_warning("GameSession: invalid speed %d" % s)
		return
	speed = s
	auto_paused_speed = 0


func submit(cmd: Command) -> CommandResult:
	var result: CommandResult = cmd.validate(state, tuning)
	if not result.ok:
		_events.append({"name": &"command_rejected", "payload": {"reason_key": result.reason_key}})
		return result
	if speed == 0:
		var ctx := TickContext.new(state, tuning)
		var snapshot: int = state.next_id
		cmd.apply(ctx)
		_emit_if_new_decision(ctx, snapshot)
		_events.append_array(ctx.events)
	else:
		_queue.append(cmd)
	return result


func advance(delta: float) -> int:
	if speed == 0:
		return 0
	_accumulator += delta * speed
	var ticks: int = int(floor(_accumulator / tuning.seconds_per_week))
	if ticks > tuning.max_ticks_per_frame:
		ticks = tuning.max_ticks_per_frame
		_accumulator = 0.0
	else:
		_accumulator -= ticks * tuning.seconds_per_week
	var ran: int = 0
	for i: int in ticks:
		step_once()
		ran += 1
		if speed == 0:
			break
	return ran


func step_once() -> void:
	var ctx := TickContext.new(state, tuning)
	var snapshot: int = state.next_id
	var queued: Array[Command] = _queue
	_queue = []
	for cmd: Command in queued:
		var result: CommandResult = cmd.validate(state, tuning)
		if result.ok:
			cmd.apply(ctx)
		else:
			ctx.emit(&"command_rejected", {"reason_key": result.reason_key})
	Simulation.step(ctx)
	if _emit_if_new_decision(ctx, snapshot) and speed > 0:
		auto_paused_speed = speed
		speed = 0
		ctx.emit(&"speed_changed", {"speed": 0})
	if Calendar.is_quarter_start(state.week, tuning):
		autosave_due = true
	_events.append_array(ctx.events)


## Spec 4.9: a decision is new when its id was allocated after the snapshot.
func _emit_if_new_decision(ctx: TickContext, snapshot: int) -> bool:
	var newest: int = -1
	for d: Decision in state.pending_decisions:
		if d.id >= snapshot and d.id > newest:
			newest = d.id
	if newest < 0:
		return false
	ctx.emit(&"decision_required", {"decision_id": newest})
	return true


func push_event(event_name: StringName, payload: Dictionary) -> void:
	_events.append({"name": event_name, "payload": payload})


func drain_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = _events
	_events = []
	return out


func can_save() -> bool:
	return _queue.is_empty()
