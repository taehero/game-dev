class_name DeskSprite
extends Node2D
## A desk with an optional computer on top. Visuals only.

const HALF_OFFSET: float = 8.0
const COMPUTER_OFFSET: Vector2 = Vector2(0, -9)

var computer_tier: int = 0

@onready var _left: Sprite2D = $DeskLeft
@onready var _right: Sprite2D = $DeskRight
@onready var _computer: Sprite2D = $Computer


func _ready() -> void:
	_left.texture = OfficeArt.atlas(OfficeArt.DESK_LEFT)
	_left.position = Vector2(-HALF_OFFSET, 0)
	_right.texture = OfficeArt.atlas(OfficeArt.DESK_RIGHT)
	_right.position = Vector2(HALF_OFFSET, 0)
	_computer.position = COMPUTER_OFFSET
	set_computer_tier(computer_tier)


func set_computer_tier(tier: int) -> void:
	computer_tier = tier
	if tier <= 0:
		_computer.visible = false
		return
	_computer.texture = OfficeArt.atlas(OfficeArt.computer_ref(tier))
	_computer.visible = true
