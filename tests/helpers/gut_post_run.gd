extends GutHookScript


func run() -> void:
	var dropped: Array[String] = []
	for w: Variant in gut.logger.get_warnings():
		if str(w).begins_with("Ignoring script "):
			dropped.append(str(w))
	if not dropped.is_empty():
		gut.logger.error("Test scripts failed to load: %s" % str(dropped))
		set_exit_code(1)
