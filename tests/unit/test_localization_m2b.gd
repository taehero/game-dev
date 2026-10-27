extends GutTest

const ERRORS: Array[String] = ["game_over", "candidate_not_found", "staff_not_found", "cannot_fire_owner",
		"no_raise_pending", "invalid_seat", "seat_taken", "equipment_not_found", "equipment_not_available",
		"seat_has_equipment", "office_not_found", "office_current", "office_too_small", "license_not_needed",
		"license_owned", "vendor_not_found", "invalid_deliverable", "already_outsourced", "contract_not_found",
		"contract_taken", "contract_expired", "lender_not_found", "invalid_amount", "over_credit_limit",
		"bank_refused", "loan_not_found", "perk_not_found", "no_skill_points", "perk_maxed", "invalid_focus"]


func after_each() -> void:
	TranslationServer.set_locale("en")


func _keys() -> Array[String]:
	var keys: Array[String] = ["ui.decision.accept", "ui.decision.refuse", "ui.contract_work.title",
			"ui.engine.outsourced_name"]
	for e: String in ERRORS:
		keys.append("error." + e)
	for i in range(1, 25):
		keys.append("staff_name.%02d" % i)
	for db_id: StringName in ContentDB.load_dir().perks:
		var short := String(db_id).trim_prefix("perk_")
		keys.append("content.perk.%s.name" % short)
		keys.append("content.perk.%s.desc" % short)
	return keys


func test_every_m2b_key_has_en_and_th() -> void:
	for key: String in _keys():
		for loc: String in ["en", "th"]:
			TranslationServer.set_locale(loc)
			var s := tr(key)
			assert_true(s != "" and s != key, "%s missing in %s" % [key, loc])
