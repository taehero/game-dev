class_name PerkDef
extends Resource

@export var id: StringName
@export var name_key: StringName
@export var path: StringName = &""
@export var max_rank: int = 0
@export var effects_bp_per_rank: Dictionary[StringName, int] = {}
