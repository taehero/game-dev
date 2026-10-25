class_name ReviewOutletDef
extends Resource

const DIMENSIONS: Array[StringName] = [&"gameplay", &"tech", &"graphics", &"audio", &"story", &"innovation", &"bugs", &"platform_fit", &"market_fit", &"value"]

@export var id: StringName
@export var name_key: StringName
@export var weights_bp: Dictionary[StringName, int] = {}
@export var bias_x10: int = 0
