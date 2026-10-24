extends GutTest

const S: Dictionary = {"id": "int", "name": "string", "rate": "float", "on": "bool", "tags": "array", "m": "dict"}


func _ok() -> Dictionary:
	return {"id": 3.0, "name": "a", "rate": 1, "on": true, "tags": [], "m": {}}


func test_accepts_json_shaped_dict() -> void:
	assert_true(SaveSchema.check(_ok(), S))


func test_rejects_missing_key() -> void:
	var d: Dictionary = _ok()
	d.erase("name")
	assert_false(SaveSchema.check(d, S))


func test_rejects_fractional_int() -> void:
	var d: Dictionary = _ok()
	d["id"] = 3.5
	assert_false(SaveSchema.check(d, S))


func test_rejects_wrong_type() -> void:
	var d: Dictionary = _ok()
	d["on"] = "yes"
	assert_false(SaveSchema.check(d, S))


func test_rejects_non_dict() -> void:
	assert_false(SaveSchema.check([1, 2], S))
