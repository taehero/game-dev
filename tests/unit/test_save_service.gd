extends GutTest

var dir: String = ""


func before_each() -> void:
	dir = "user://test_saves_%d" % Time.get_ticks_usec()


func after_each() -> void:
	var abs_dir: String = ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(abs_dir):
		for f: String in DirAccess.get_files_at(abs_dir):
			DirAccess.remove_absolute(abs_dir.path_join(f))
		DirAccess.remove_absolute(abs_dir)


func _parsed() -> Dictionary:
	return JSON.parse_string(SaveService.serialize(Fixtures.new_state(11)))


func test_serialize_deserialize_round_trip_keeps_hash() -> void:
	var s := Fixtures.new_state(11)
	Fixtures.add_staff(s)
	var r := SaveService.deserialize(SaveService.serialize(s))
	assert_true(r.ok)
	assert_eq(StateHash.of(r.state), StateHash.of(s))


func test_truncated_json_is_unreadable() -> void:
	var text := SaveService.serialize(Fixtures.new_state(11))
	assert_eq(SaveService.deserialize(text.substr(0, text.length() / 2)).error_key, &"error.save_unreadable")


func test_non_dict_is_unreadable() -> void:
	assert_eq(SaveService.deserialize("[1,2]").error_key, &"error.save_unreadable")


func test_newer_version_refused() -> void:
	var d := _parsed()
	d["schema_version"] = SaveService.SCHEMA_VERSION + 1
	assert_eq(SaveService.deserialize(JSON.stringify(d)).error_key, &"error.save_newer_version")


func test_wrong_type_is_invalid() -> void:
	var d := _parsed()
	d["state"]["week"] = "ten"
	assert_eq(SaveService.deserialize(JSON.stringify(d)).error_key, &"error.save_invalid")


func test_migration_runs_for_older_version() -> void:
	var d := _parsed()
	d["schema_version"] = 0
	SaveService.migrations[0] = func(st: Dictionary) -> Dictionary:
		st["week"] = 7
		return st
	var r := SaveService.deserialize(JSON.stringify(d))
	SaveService.migrations.erase(0)
	assert_true(r.ok)
	assert_eq(r.state.week, 7)


func test_slot_names_reject_path_traversal() -> void:
	assert_false(SaveService.is_valid_slot("../../x"))
	assert_false(SaveService.is_valid_slot("slot_10"))
	assert_true(SaveService.is_valid_slot("slot_3"))
	assert_true(SaveService.is_valid_slot("autosave"))
	assert_eq(SaveService.save_to_slot(Fixtures.new_state(1), "../x", dir), ERR_INVALID_PARAMETER)


func test_save_and_load_slot() -> void:
	var s := Fixtures.new_state(11)
	assert_eq(SaveService.save_to_slot(s, "slot_1", dir), OK)
	assert_false(FileAccess.file_exists(dir + "/slot_1.json.tmp"))
	assert_eq(StateHash.of(SaveService.load_from_slot("slot_1", dir).state), StateHash.of(s))


func test_overwrite_existing_slot_replaces_file() -> void:
	var a := Fixtures.new_state(11)
	var b := Fixtures.new_state(12)
	assert_eq(SaveService.save_to_slot(a, "slot_1", dir), OK)
	assert_eq(SaveService.save_to_slot(b, "slot_1", dir), OK)
	assert_eq(StateHash.of(SaveService.load_from_slot("slot_1", dir).state), StateHash.of(b))
	assert_false(FileAccess.file_exists(dir + "/slot_1.json.tmp"))


func test_failed_write_keeps_previous_save() -> void:
	var s := Fixtures.new_state(11)
	SaveService.save_to_slot(s, "slot_1", dir)
	# simulate a crash mid-write: a stale tmp file exists, the real file must still load
	var f := FileAccess.open(dir + "/slot_1.json.tmp", FileAccess.WRITE)
	f.store_string("{\"trunc")
	f.close()
	assert_true(SaveService.load_from_slot("slot_1", dir).ok)


func test_missing_slot_is_unreadable() -> void:
	assert_eq(SaveService.load_from_slot("slot_9", dir).error_key, &"error.save_unreadable")
