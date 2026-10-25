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


func test_staff_look_is_stable_back_view() -> void:
	var sprite := _staff()
	sprite.set_look(7)
	var first: Rect2 = (sprite.get_node("Body") as Sprite2D).texture.region
	sprite.set_look(7)
	var second: Rect2 = (sprite.get_node("Body") as Sprite2D).texture.region
	assert_eq(first, second)
	assert_eq(first, Rect2(OfficeArt.region(OfficeArt.body_ref(7))))


func test_chair_drawn_over_body() -> void:
	var sprite := _staff()
	var body := sprite.get_node("Body") as Sprite2D
	var chair := sprite.get_node("Chair") as Sprite2D
	assert_gt(chair.get_index(), body.get_index())
	assert_eq(chair.position, StaffSprite.CHAIR_OFFSET)
	assert_eq(chair.texture.region, OfficeArt.chair_overlay().region)


func test_bob_moves_body_not_chair() -> void:
	var sprite := _staff()
	var body := sprite.get_node("Body") as Sprite2D
	var chair := sprite.get_node("Chair") as Sprite2D
	sprite.set_pose(StateQueries.StaffPose.WORKING)
	await wait_seconds(0.3)
	assert_eq(chair.position, StaffSprite.CHAIR_OFFSET)
	assert_true(body.position.y <= StaffSprite.BODY_OFFSET.y)
	sprite.set_pose(StateQueries.StaffPose.IDLE)
	assert_eq(body.position, StaffSprite.BODY_OFFSET)


func test_desk_tier_zero_hides_computer() -> void:
	var desk := _desk()
	desk.set_computer_tier(0)
	assert_false((desk.get_node("Computer") as Sprite2D).visible)
	assert_eq(desk.computer_tier, 0)


func test_desk_is_two_tiles_centred() -> void:
	var desk := _desk()
	var left := desk.get_node("DeskLeft") as Sprite2D
	var right := desk.get_node("DeskRight") as Sprite2D
	assert_eq(left.position.x, -8.0)
	assert_eq(right.position.x, 8.0)
	assert_eq(left.texture.region, Rect2(OfficeArt.region(OfficeArt.DESK_LEFT)))
	assert_eq(right.texture.region, Rect2(OfficeArt.region(OfficeArt.DESK_RIGHT)))


func test_desk_tier_picks_computer_ref() -> void:
	var desk := _desk()
	var comp := desk.get_node("Computer") as Sprite2D
	desk.set_computer_tier(2)
	assert_true(comp.visible)
	assert_eq(comp.position, DeskSprite.COMPUTER_OFFSET)
	assert_eq(comp.texture.region, Rect2(OfficeArt.region(OfficeArt.computer_ref(2))))
	desk.set_computer_tier(7)
	assert_eq(comp.texture.region, Rect2(OfficeArt.region(OfficeArt.computer_ref(3))))
