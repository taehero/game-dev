extends GutTest


func test_real_content_still_valid() -> void:
	var db := ContentDB.load_dir()
	assert_eq(db.errors, [] as Array[String])
	assert_eq(db.validate(), [] as Array[String])


func test_m2c_channels_award_size() -> void:
	var db := ContentDB.load_dir()
	assert_eq(db.channels.size(), 4)
	assert_eq(db.channels[&"channel_trade_show"].weeks_in_year, [22, 23, 24, 25] as Array[int])
	assert_eq(db.awards[&"award_golden_cartridge"].week_in_year, 50)
	assert_true(db.sizes[&"size_dlc"].dlc)
	assert_true(db.is_unlocked([], &"channel_magazine_ad"))
	assert_false(db.is_unlocked([], &"channel_tv_spot"))
	for id: StringName in GameState.sorted_names(db.channels):
		assert_ne(tr(db.channels[id].name_key), String(db.channels[id].name_key))
	for id: StringName in GameState.sorted_names(db.awards):
		assert_ne(tr(db.awards[id].name_key), String(db.awards[id].name_key))
