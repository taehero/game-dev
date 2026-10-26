class_name ProductionEventDef
extends Resource
## A mid-production event with 2-3 options. Effects are small integer deltas on a project.

const EFFECTS: Array[StringName] = [&"design", &"tech", &"art", &"audio", &"bugs", &"hype", &"morale", &"progress_bp"]
const LIMITS: Dictionary[StringName, int] = {&"design": 500, &"tech": 500, &"art": 500, &"audio": 500,
	&"bugs": 20, &"hype": 20, &"morale": 20, &"progress_bp": 5000}  # absolute max per effect

@export var id: StringName
@export var title_key: StringName
@export var body_key: StringName
@export var option_keys: Array[StringName] = []
@export var option_a: Dictionary[StringName, int] = {}
@export var option_b: Dictionary[StringName, int] = {}
@export var option_c: Dictionary[StringName, int] = {}


func option_effects(i: int) -> Dictionary[StringName, int]:
	match i:
		0:
			return option_a
		1:
			return option_b
		2:
			return option_c
	var none: Dictionary[StringName, int] = {}
	return none
