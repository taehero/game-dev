extends GutTest


func test_every_def_class_has_id_and_no_float_exports() -> void:
	for cls: GDScript in [PlatformDef, GenreDef, TopicDef, ReviewOutletDef, ReviewTemplateDef, OfficeDef,
			EquipmentDef, EngineFeatureDef, LicensedEngineDef, ResearchDef, ProjectSizeDef, LevelDef,
			PerkDef, MarketingChannelDef, AwardDef]:
		var r: Resource = cls.new()
		var names: Array = r.get_property_list().map(func(p: Dictionary) -> String: return p["name"])
		assert_has(names, "id", cls.resource_path)
		for p: Dictionary in r.get_property_list():
			if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
				assert_ne(p["type"], TYPE_FLOAT, "%s.%s is float" % [cls.resource_path, p["name"]])


func test_dimensions_are_the_ten_foundation_dimensions() -> void:
	assert_eq(ReviewOutletDef.DIMENSIONS.size(), 10)
	assert_eq(ReviewOutletDef.DIMENSIONS[0], &"gameplay")
