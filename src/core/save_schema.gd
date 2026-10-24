class_name SaveSchema
extends RefCounted
## Validates dictionaries parsed from JSON (all numbers are float, keys are String).
## schema maps field name -> type tag: "int", "float", "string", "bool", "dict", "array".


static func check(d: Variant, schema: Dictionary) -> bool:
	if typeof(d) != TYPE_DICTIONARY:
		return false
	var dict: Dictionary = d
	for key: Variant in schema:
		if not dict.has(key):
			return false
		if not _matches(dict[key], String(schema[key])):
			return false
	return true


## True for an int, or a float with no fraction (how JSON delivers whole numbers).
static func is_whole(v: Variant) -> bool:
	return _matches(v, "int")


static func _matches(v: Variant, tag: String) -> bool:
	var t: int = typeof(v)
	match tag:
		"int":
			if t == TYPE_INT:
				return true
			if t == TYPE_FLOAT:
				var f: float = v
				return is_finite(f) and f == floorf(f)
			return false
		"float":
			return t == TYPE_INT or t == TYPE_FLOAT
		"string":
			return t == TYPE_STRING or t == TYPE_STRING_NAME
		"bool":
			return t == TYPE_BOOL
		"dict":
			return t == TYPE_DICTIONARY
		"array":
			return t == TYPE_ARRAY
	return false
