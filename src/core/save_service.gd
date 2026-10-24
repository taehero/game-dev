class_name SaveService
extends RefCounted
## JSON save files. Stateless apart from the migrations registry.

const SCHEMA_VERSION: int = 1
const DEFAULT_DIR: String = "user://saves"

## Key n migrates a version-n state dict to version n + 1.
static var migrations: Dictionary[int, Callable] = {}


static func serialize(state: GameState) -> String:
	return JSON.stringify({"schema_version": SCHEMA_VERSION, "state": state.to_dict()}, "", true, true)


static func deserialize(text: String) -> LoadResult:
	var json := JSON.new()
	if json.parse(text) != OK:
		return LoadResult.failure(&"error.save_unreadable")
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return LoadResult.failure(&"error.save_unreadable")
	var root: Dictionary = parsed
	if not root.has("schema_version") or not SaveSchema.is_whole(root["schema_version"]):
		return LoadResult.failure(&"error.save_unreadable")
	if typeof(root.get("state")) != TYPE_DICTIONARY:
		return LoadResult.failure(&"error.save_unreadable")
	var version: int = int(root["schema_version"])
	if version > SCHEMA_VERSION:
		return LoadResult.failure(&"error.save_newer_version")
	var state_dict: Dictionary = root["state"]
	while version < SCHEMA_VERSION:
		if not migrations.has(version):
			return LoadResult.failure(&"error.save_invalid")
		var migrated: Variant = migrations[version].call(state_dict)
		if typeof(migrated) != TYPE_DICTIONARY:
			return LoadResult.failure(&"error.save_invalid")
		state_dict = migrated
		version += 1
	if not GameState.validate_dict(state_dict):
		return LoadResult.failure(&"error.save_invalid")
	return LoadResult.success(GameState.from_dict(state_dict))


static func is_valid_slot(slot: String) -> bool:
	var re := RegEx.new()
	re.compile("^(slot_[1-9]|autosave)$")
	return re.search(slot) != null


static func save_to_slot(state: GameState, slot: String, dir: String = DEFAULT_DIR) -> Error:
	if not is_valid_slot(slot):
		return ERR_INVALID_PARAMETER
	var made: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	if made != OK:
		return made
	var final_path: String = dir.path_join(slot + ".json")
	var tmp_path: String = final_path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(serialize(state))
	var write_err: Error = f.get_error()
	f.close()
	if write_err != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
		return write_err
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(final_path))


static func load_from_slot(slot: String, dir: String = DEFAULT_DIR) -> LoadResult:
	if not is_valid_slot(slot):
		return LoadResult.failure(&"error.save_unreadable")
	var path: String = dir.path_join(slot + ".json")
	if not FileAccess.file_exists(path):
		return LoadResult.failure(&"error.save_unreadable")
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return LoadResult.failure(&"error.save_unreadable")
	var text: String = f.get_as_text()
	f.close()
	return deserialize(text)
