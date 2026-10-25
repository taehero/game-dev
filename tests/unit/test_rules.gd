extends GutTest
## Architecture rule tests: scan source text for CLAUDE.md hard-rule violations.

func test_regexes_catch_known_bad_strings() -> void:
	assert_true(RuleScan.matches(RuleScan.GLOBAL_RNG, "var x := randi() % 3"))
	assert_true(RuleScan.matches(RuleScan.GLOBAL_RNG, "randomize()"))
	assert_true(RuleScan.matches(RuleScan.GLOBAL_RNG, "x = randf_range(0.0, 1.0)"))
	assert_true(RuleScan.matches(RuleScan.RESOURCE_IO, "ResourceSaver.save(r, p)"))
	assert_true(RuleScan.matches(RuleScan.RESOURCE_IO, "ResourceLoader.load(p)"))
	assert_true(RuleScan.matches(RuleScan.FLOAT_WORD, "var x: float = 1.0"))
	assert_true(RuleScan.matches(RuleScan.TRIG_POW, "pow(2, 3)"))
	assert_true(RuleScan.matches(RuleScan.TRIG_POW, "var y = sin(x)"))
	assert_true(RuleScan.matches(RuleScan.STATE_WRITE, "state.cash = 5"))
	assert_true(RuleScan.matches(RuleScan.STATE_WRITE, "state.staff[3].morale -= 1"))
	assert_true(RuleScan.matches(RuleScan.TRIG_POW, "acos(x)"))
	assert_true(RuleScan.matches(RuleScan.TRIG_POW, "tan(x)"))
	assert_true(RuleScan.matches(RuleScan.TRIG_POW, "sqrt(x)"))
	assert_true(RuleScan.matches(RuleScan.TRIG_POW, "var a = sinh(x)"))
	assert_true(RuleScan.matches(RuleScan.STATE_WRITE, "game_state.cash = 5"))
	assert_true(RuleScan.matches(RuleScan.STATE_WRITE, "_state.cash = 5"))
	for op: String in ["%=", "|=", "&=", "^=", "<<=", ">>=", "**=", "+=", "/="]:
		assert_true(RuleScan.matches(RuleScan.STATE_WRITE, "state.cash " + op + " 2"), op)
	assert_true(RuleScan.matches(RuleScan.STATE_WRITE, "state.staff[a + 1].morale = 3"))
	assert_true(RuleScan.matches(RuleScan.GLOBAL_RNG_EXTRA, "var r := randfn(0.0, 1.0)"))
	assert_true(RuleScan.matches(RuleScan.GLOBAL_RNG_EXTRA, "seed(5)"))
	assert_true(RuleScan.matches(RuleScan.GLOBAL_RNG_EXTRA, "ids.shuffle()"))
	assert_true(RuleScan.matches(RuleScan.GLOBAL_RNG_EXTRA, "var x = ids.pick_random()"))
	assert_true(RuleScan.matches(RuleScan.FLOAT_LITERAL, "var m := 0.5"))

func test_regexes_allow_known_good_strings() -> void:
	assert_false(RuleScan.matches(RuleScan.GLOBAL_RNG, "return rng.randi_range(0, 9)"))
	assert_false(RuleScan.matches(RuleScan.GLOBAL_RNG, "var my_randi_value := 3"))
	assert_false(RuleScan.matches(RuleScan.FLOAT_WORD, "var floating_x: int = 1"))
	assert_false(RuleScan.matches(RuleScan.TRIG_POW, "var d := _log(x)"))
	assert_false(RuleScan.matches(RuleScan.STATE_WRITE, "if state.cash == 5:"))
	assert_false(RuleScan.matches(RuleScan.STATE_WRITE, "if state.cash != 5 and state.week <= 3:"))
	assert_false(RuleScan.matches(RuleScan.STATE_WRITE, "if state.cash >= 5 or state.staff[a + 1].x == 2:"))
	assert_false(RuleScan.matches(RuleScan.STATE_WRITE, "var c := state.cash"))
	assert_false(RuleScan.matches(RuleScan.TRIG_POW, "Fixed.mul_bp(a, b)"))
	assert_false(RuleScan.matches(RuleScan.TRIG_POW, "var cosine_value := 3"))
	assert_false(RuleScan.matches(RuleScan.GLOBAL_RNG_EXTRA, "rng.seed = 5"))
	assert_false(RuleScan.matches(RuleScan.GLOBAL_RNG_EXTRA, "var p_seed := 5"))
	assert_false(RuleScan.matches(RuleScan.FLOAT_LITERAL, "var v := a1.5x"))
	assert_false(RuleScan.matches(RuleScan.FLOAT_LITERAL, "var n := 15"))

func test_entity_erase_regex() -> void:
	assert_true(RuleScan.matches(RuleScan.ENTITY_ERASE, "state.staff.erase(id)"))
	assert_false(RuleScan.matches(RuleScan.ENTITY_ERASE, "d.erase(\"name\")"))

func test_comment_stripping() -> void:
	assert_eq(RuleScan.strip_comment("var a := 1  # float here"), "var a := 1  ")
	assert_eq(RuleScan.strip_comment("## float docs"), "")
	assert_eq(RuleScan.strip_comment("var s := \"a # b\" # c"), "var s := \"a # b\" ")

func _assert_clean(paths: Array[String], pattern: String, rule: String, exclude: Array[String] = []) -> void:
	var report := RuleScan.scan(paths, pattern, exclude)
	var hits: Array[String] = report["hits"]
	assert_eq(hits.size(), 0, "%s violated:\n%s" % [rule, "\n".join(hits)])
	# A scan that read nothing proves nothing: every root that exists must yield files.
	for root: String in paths:
		if RuleScan.root_exists(root):
			var one := RuleScan.scan([root] as Array[String], pattern, exclude)
			assert_gt(int(one["files"]), 0, "%s: no .gd files read under %s" % [rule, root])

func test_scan_roots_contain_gd_files() -> void:
	for root: String in ["res://src/core", "res://src/core/entities", "res://src/systems", "res://src/ui"]:
		var report := RuleScan.scan([root] as Array[String], "zzz_never_matches_zzz")
		assert_gt(int(report["files"]), 0, "no .gd files read under %s" % root)

func test_missing_scan_root_reads_zero_files_without_failing() -> void:
	var report := RuleScan.scan(["res://src/does_not_exist_yet"] as Array[String], RuleScan.GLOBAL_RNG)
	assert_eq(int(report["files"]), 0)
	assert_eq((report["hits"] as Array).size(), 0)

func test_no_global_rng_in_core_and_systems() -> void:
	_assert_clean(["res://src/core", "res://src/systems"], RuleScan.GLOBAL_RNG, "global RNG")

func test_no_resource_io_in_save_service() -> void:
	_assert_clean(["res://src/core/save_service.gd"], RuleScan.RESOURCE_IO, "ResourceSaver/Loader in saves")

func test_no_other_global_rng_in_core_and_systems() -> void:
	_assert_clean(["res://src/core", "res://src/systems"], RuleScan.GLOBAL_RNG_EXTRA, "randfn/seed/shuffle/pick_random")

func test_no_floats_in_state() -> void:
	var paths: Array[String] = ["res://src/core/entities", "res://src/core/game_state.gd"]
	_assert_clean(paths, RuleScan.FLOAT_WORD, "float in state")
	_assert_clean(paths, RuleScan.FLOAT_LITERAL, "float literal in state")

func test_no_float_math_in_core_and_systems() -> void:
	_assert_clean(["res://src/core", "res://src/systems"], RuleScan.TRIG_POW, "float math in core/systems")

func test_no_direct_state_writes_in_ui() -> void:
	_assert_clean(["res://src/ui"], RuleScan.STATE_WRITE, "direct state write in UI")

func test_entity_removal_only_in_removal_gd() -> void:
	_assert_clean(["res://src"], RuleScan.ENTITY_ERASE, "entity erase outside removal.gd", ["res://src/core/removal.gd"])

class RuleScan:
	const GLOBAL_RNG := "(?<![\\w.])(randi|randf|randomize|randi_range|randf_range)\\s*\\("
	const RESOURCE_IO := "ResourceSaver|ResourceLoader"
	## Known limit: only identifiers ending in "state." match; aliases (var s := state) are not caught.
	const ENTITY_ERASE := "\\b\\w*state\\.(staff|equipment|contracts|loans|projects)\\.erase\\s*\\("
	const FLOAT_WORD := "\\bfloat\\b"
	const GLOBAL_RNG_EXTRA := "(?<![\\w.])(randfn|seed)\\s*\\(|\\.(shuffle|pick_random)\\s*\\("
	const FLOAT_LITERAL := "(?<![\\w.])\\d+\\.\\d"
	const TRIG_POW := "(?<!\\w)(pow|exp|exp2|log|sqrt|sin|cos|tan|asin|acos|atan|atan2|sinh|cosh|tanh)\\s*\\("
	## Known limit: method-call mutations (.erase(), .append()) and aliased writes
	## (var s := state; s.x = 1) cannot be caught by a line regex.
	const STATE_WRITE := "\\b\\w*state\\.[\\w.\\[\\]\"&+*/%|^\\- ]*?\\s*(?:<<|>>|\\*\\*|[-+*/%|&^])?=[^=]"

	static func matches(pattern: String, text: String) -> bool:
		var re := RegEx.create_from_string(pattern)
		return re != null and re.search(text) != null

	## Removes a trailing # or ## comment, ignoring # inside string literals.
	static func strip_comment(line: String) -> String:
		var quote := ""
		for i: int in line.length():
			var c := line[i]
			if quote != "":
				if c == "\\":
					continue
				if c == quote and (i == 0 or line[i - 1] != "\\"):
					quote = ""
			elif c == "\"" or c == "'":
				quote = c
			elif c == "#":
				return line.substr(0, i)
		return line

	static func gd_files(path: String) -> Array[String]:
		var out: Array[String] = []
		if FileAccess.file_exists(path):
			if path.ends_with(".gd"):
				out.append(path)
			return out
		var dir := DirAccess.open(path)
		if dir == null:
			return out
		var names := dir.get_files()
		names.sort()
		for n: String in names:
			if n.ends_with(".gd"):
				out.append(path.path_join(n))
		var subs := dir.get_directories()
		subs.sort()
		for d: String in subs:
			out.append_array(gd_files(path.path_join(d)))
		return out

	static func root_exists(path: String) -> bool:
		return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)

	## Returns {"hits": Array[String] of "path:line: text" for every code line (comments
	## stripped) matching pattern, "files": number of .gd files actually read}.
	static func scan(paths: Array[String], pattern: String, exclude: Array[String] = []) -> Dictionary:
		var hits: Array[String] = []
		var files_read: int = 0
		var re := RegEx.create_from_string(pattern)
		for root: String in paths:
			for f: String in gd_files(root):
				if exclude.has(f):
					continue
				var fa := FileAccess.open(f, FileAccess.READ)
				if fa == null:
					continue
				files_read += 1
				var lines := fa.get_as_text().split("\n")
				for i: int in lines.size():
					var code := strip_comment(lines[i])
					if re.search(code) != null:
						hits.append("%s:%d: %s" % [f, i + 1, code.strip_edges()])
		return {"hits": hits, "files": files_read}
