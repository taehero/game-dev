class_name DeskSprite
extends Node2D
## A desk with an optional computer on top. Visuals only.

const COMPUTER_OFFSET: Vector2 = Vector2(0, -4)

var computer_tier: int = 0

@onready var _desk: Sprite2D = $Desk
@onready var _computer: Sprite2D = $Computer


func _ready() -> void:
	_desk.texture = OfficeArt.atlas(OfficeArt.DESK)
	_computer.position = COMPUTER_OFFSET
	set_computer_tier(computer_tier)


func set_computer_tier(tier: int) -> void:
	computer_tier = tier
	if tier <= 0:
		_computer.visible = false
		return
	_computer.texture = OfficeArt.atlas(OfficeArt.computer_cell(tier))
	_computer.visible = true
