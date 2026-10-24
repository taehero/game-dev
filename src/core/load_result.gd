class_name LoadResult
extends RefCounted
## Outcome of loading a save. On failure, error_key is a locale key.

var ok: bool = false
var state: GameState = null
var error_key: StringName = &""


static func success(p_state: GameState) -> LoadResult:
	var r := LoadResult.new()
	r.ok = true
	r.state = p_state
	return r


static func failure(p_error_key: StringName) -> LoadResult:
	var r := LoadResult.new()
	r.error_key = p_error_key
	return r
