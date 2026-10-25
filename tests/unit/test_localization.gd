extends GutTest

const M2A_ERROR_KEYS: Array[String] = [
		"error.no_free_seat",
		"error.not_enough_money",
		"error.not_enough_rp",
		"error.research_not_found",
		"error.research_done",
		"error.research_locked",
		"error.platform_not_found",
		"error.platform_not_on_sale",
		"error.dev_kit_owned",
		"error.no_dev_kit",
		"error.title_empty",
		"error.size_not_found",
		"error.topic_not_found",
		"error.genre_not_found",
		"error.feature_not_found",
		"error.item_locked",
		"error.engine_unavailable",
		"error.feature_not_in_engine",
		"error.no_features",
		"error.not_enough_staff",
		"error.project_not_found",
		"error.project_not_in_production",
		"error.invalid_sliders",
		"error.past_stage_locked",
		"error.project_not_ready",
		"error.save_content_missing"]

func after_each() -> void:
	TranslationServer.set_locale("en")

func test_thai_translation_loads() -> void:
	TranslationServer.set_locale("th")
	assert_eq(tr("ui.hud.hire"), "จ้างคน")

func test_every_error_key_has_en_and_th() -> void:
	for key: String in ["error.company_not_found", "error.invalid_salary", "error.staff_limit",
			"error.save_unreadable", "error.save_newer_version", "error.save_invalid"] + M2A_ERROR_KEYS:
		TranslationServer.set_locale("en")
		assert_ne(tr(key), key)
		TranslationServer.set_locale("th")
		assert_ne(tr(key), key)
