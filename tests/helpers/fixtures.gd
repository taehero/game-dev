class_name Fixtures
extends RefCounted
## Shared test helpers. Not a test file.


static func json_round_trip(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d, "", true, true))
