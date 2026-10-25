class_name StaffSprite
extends Node2D
## One staff member in the office. Visuals only; pose comes from StateQueries.staff_pose.

const BOB_HEIGHT: float = 1.0
const WORKING_PERIOD: float = 0.5
const CRUNCH_PERIOD: float = 0.25

var pose: StateQueries.StaffPose = StateQueries.StaffPose.IDLE

var _tween: Tween = null

@onready var _body: Sprite2D = $Body


func set_look(staff_id: int) -> void:
	_body.texture = OfficeArt.atlas(OfficeArt.body_ref(staff_id))


func set_pose(p: StateQueries.StaffPose) -> void:
	pose = p
	if _tween != null:
		_tween.kill()
		_tween = null
	_body.position.y = 0.0
	match p:
		StateQueries.StaffPose.IDLE:
			_body.modulate = Color.WHITE
		StateQueries.StaffPose.WORKING:
			_body.modulate = Color.WHITE
			_start_bob(WORKING_PERIOD)
		StateQueries.StaffPose.CRUNCHING:
			_body.modulate = Color(1, 0.8, 0.8)
			_start_bob(CRUNCH_PERIOD)
		StateQueries.StaffPose.BURNED_OUT:
			_body.modulate = Color(0.6, 0.6, 0.7)


func is_bobbing() -> bool:
	return _tween != null and _tween.is_valid()


func _start_bob(period: float) -> void:
	_tween = create_tween().set_loops()
	_tween.tween_property(_body, "position:y", -BOB_HEIGHT, period * 0.5)
	_tween.tween_property(_body, "position:y", 0.0, period * 0.5)
