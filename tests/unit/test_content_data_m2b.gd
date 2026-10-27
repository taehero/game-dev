extends GutTest


func test_m2b_perks_and_equipment_years() -> void:
	var db := ContentDB.load_dir()
	assert_eq(db.perks.size(), 11)
	for id: StringName in db.perks:
		assert_ne(tr(db.perks[id].name_key), String(db.perks[id].name_key))
	assert_eq(db.perks[&"perk_promoter"].effects_bp_per_rank[&"hype_gain_bp"], 1500)
	assert_eq(db.equipment[&"equipment_micro_1985"].year_from, 1985)
	assert_eq(db.equipment[&"equipment_micro_1980"].year_from, 1978)
	assert_eq(db.validate(), [] as Array[String])
