class_name MarketingChannelDef
extends Resource

@export var id: StringName
@export var name_key: StringName
@export var year_from: int = 0
@export var year_to: int = 0
@export var cost: int = 0
@export var hype_gain: int = 0
@export var segment: StringName = &""
@export var weeks_in_year: Array[int] = []  # empty = any week
