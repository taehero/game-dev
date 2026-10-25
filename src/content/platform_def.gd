class_name PlatformDef
extends Resource

@export var id: StringName
@export var name_key: StringName
@export var kind: StringName = &""
@export var launch_week: int = 0
@export var end_week: int = 0
@export var owner_company_id: int = -1
@export var install_curve: Array[int] = []
@export var tech_ceiling: int = 0
@export var handheld: bool = false
@export var dev_kit_cost: int = 0
@export var rumor_weeks: int = 0
@export var genre_fit_bp: Dictionary[StringName, int] = {}
