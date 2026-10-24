class_name CommandResult
extends RefCounted

var ok: bool = true
var reason_key: StringName = &""


static func success() -> CommandResult:
	return CommandResult.new()


static func fail(key: StringName) -> CommandResult:
	var r := CommandResult.new()
	r.ok = false
	r.reason_key = key
	return r
