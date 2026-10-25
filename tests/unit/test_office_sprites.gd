extends GutTest

const STAFF_SCENE: PackedScene = preload("res://src/ui/office/staff_sprite.tscn")
const DESK_SCENE: PackedScene = preload("res://src/ui/office/desk_sprite.tscn")


func _staff() -> StaffSprite:
	return add_child_autofree(STAFF_SCENE.instantiate()) as StaffSprite


func _desk() -> DeskSprite:
	return add_child_autofree(DESK_SCENE.instantiate()) as DeskSprite


func test_staff_sprite_pose_sets_modulate_and_bob() -> void:
	var sprite := _staff()
	var cases: Array = [
		[StateQueries.StaffPose.IDLE, Color.WHITE, false],
		[StateQueries.StaffPose.WORKING, Color.WHITE, true],
		[StateQueries.StaffPose.CRUNCHING, Color(1, 0.8, 0.8), true],
		[StateQueries.StaffPose.BURNED_OUT, Color(0.6, 0.6, 0.7), false],
	]
	for c: Array in cases:
		sprite.set_pose(c[0])
		assert_eq(sprite.pose, c[0])
		assert_eq(sprite.get_node("Body").modulate, c[1])
		assert_eq(sprite.is_bobbing(), c[2])


func test_staff_look_is_stable_per_id() -> void:
	var sprite := _staff()
	sprite.set_look(7)
	var first: Rect2 = (sprite.get_node("Body") as Sprite2D).texture.region
	sprite.set_look(7)
	var second: Rect2 = (sprite.get_node("Body") as Sprite2D).texture.region
	assert_eq(first, second)
	assert_eq(first, Rect2(OfficeArt.region(OfficeArt.body_cell(7))))


func test_desk_tier_zero_hides_computer() -> void:
	var desk := _desk()
	desk.set_computer_tier(0)
	assert_false((desk.get_node("Computer") as Sprite2D).visible)
	assert_eq(desk.computer_tier, 0)


func test_desk_tier_picks_computer_cell() -> void:
	var desk := _desk()
	desk.set_computer_tier(2)
	var comp := desk.get_node("Computer") as Sprite2D
	assert_true(comp.visible)
	assert_eq(comp.texture.region, Rect2(OfficeArt.region(OfficeArt.computer_cell(2))))
