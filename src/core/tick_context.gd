class_name TickContext
extends RefCounted

var state: GameState
var rng: RandomNumberGenerator
var tuning: TuningDef
var content: ContentDB
var events: Array[Dictionary] = []


func _init(p_state: GameState, p_tuning: TuningDef) -> void:
	state = p_state
	rng = p_state.rng
	tuning = p_tuning
	content = ContentDB.active()


func emit(name: StringName, payload: Dictionary = {}) -> void:
	events.append({"name": name, "payload": payload})
