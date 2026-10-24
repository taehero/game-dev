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

func test_regexes_allow_known_good_strings() -> void:
	assert_false(RuleScan.matches(RuleScan.GLOBAL_RNG, "return rng.randi_range(0, 9)"))
	assert_false(RuleScan.matches(RuleScan.GLOBAL_RNG, "var my_randi_value := 3"))
	assert_false(RuleScan.matches(RuleScan.FLOAT_WORD, "var floating_x: int = 1"))
	assert_false(RuleScan.matches(RuleScan.TRIG_POW, "var d := _log(x)"))
	assert_false(RuleScan.matches(RuleScan.STATE_WRITE, "if state.cash == 5:"))
	assert_false(RuleScan.matches(RuleScan.STATE_WRITE, "if state.cash != 5 and state.week <= 3:"))

func test_comment_stripping() -> void:
	assert_eq(RuleScan.strip_comment("var a := 1  # float here"), "var a := 1  ")
	assert_eq(RuleScan.strip_comment("## float docs"), "")
	assert_eq(RuleScan.strip_comment("var s := \"a # b\" # c"), "var s := \"a # b\" ")

func _assert_clean(paths: Array[String], pattern: String, rule: String) -> void:
	var hits := RuleScan.scan(paths, pattern)
	assert_eq(hits.size(), 0, "%s violated:\n%s" % [rule, "\n".join(hits)])

func test_no_global_rng_in_core_and_systems() -> void:
	_assert_clean(["res://src/core", "res://src/systems"], RuleScan.GLOBAL_RNG, "global RNG")

func test_no_resource_io_in_save_service() -> void:
	_assert_clean(["res://src/core/save_service.gd"], RuleScan.RESOURCE_IO, "ResourceSaver/Loader in saves")

func test_no_floats_in_state() -> void:
	_assert_clean(["res://src/core/entities", "res://src/core/game_state.gd"], RuleScan.FLOAT_WORD, "float in state")

func test_no_float_math_in_systems() -> void:
	_assert_clean(["res://src/systems"], RuleScan.TRIG_POW, "pow/exp/log/sin/cos in systems")

func test_no_direct_state_writes_in_ui() -> void:
	_assert_clean(["res://src/ui"], RuleScan.STATE_WRITE, "direct state write in UI")

class RuleScan:
	const GLOBAL_RNG := "(?<![\\w.])(randi|randf|randomize|randi_range|randf_range)\\s*\\("
	const RESOURCE_IO := "ResourceSaver|ResourceLoader"
	const FLOAT_WORD := "\\bfloat\\b"
	const TRIG_POW := "(?<!\\w)(pow|exp|log|sin|cos)\\s*\\("
	const STATE_WRITE := "\\bstate\\.[\\w.\\[\\]\"&]+\\s*[-+*/]?=[^=]"

	static func matches(pattern: String, text: String) -> bool:
		var re := RegEx.create_from_string(pattern)
		return re != null and re.search(text) != null

	## Removes a trailing # or ## comment, ignoring # inside string literals.
	static func strip_comment(line: String) -> String:
		var quote := ""
		for i in line.length():
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
		for n in names:
			if n.ends_with(".gd"):
				out.append(path.path_join(n))
		var subs := dir.get_directories()
		subs.sort()
		for d in subs:
			out.append_array(gd_files(path.path_join(d)))
		return out

	## Returns "path:line: text" for every code line (comments stripped) matching pattern.
	static func scan(paths: Array[String], pattern: String) -> Array[String]:
		var hits: Array[String] = []
		var re := RegEx.create_from_string(pattern)
		for root in paths:
			for f in gd_files(root):
				var fa := FileAccess.open(f, FileAccess.READ)
				if fa == null:
					continue
				var lines := fa.get_as_text().split("\n")
				for i in lines.size():
					var code := strip_comment(lines[i])
					if re.search(code) != null:
						hits.append("%s:%d: %s" % [f, i + 1, code.strip_edges()])
		return hits
