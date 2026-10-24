extends GutTest

func after_each() -> void:
	TranslationServer.set_locale("en")

func test_thai_translation_loads() -> void:
	TranslationServer.set_locale("th")
	assert_eq(tr("ui.hud.hire"), "จ้างคน")

func test_every_error_key_has_en_and_th() -> void:
	for key: String in ["error.company_not_found", "error.invalid_salary", "error.staff_limit",
			"error.save_unreadable", "error.save_newer_version", "error.save_invalid"]:
		TranslationServer.set_locale("en")
		assert_ne(tr(key), key)
		TranslationServer.set_locale("th")
		assert_ne(tr(key), key)
