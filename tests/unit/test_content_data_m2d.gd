extends GutTest
## Real M2d production event content.

const EVENT_IDS: Array[StringName] = [&"pevent_big_bug", &"pevent_bold_idea", &"pevent_magazine_preview",
		&"pevent_power_cut", &"pevent_sound_trick", &"pevent_late_night"]


func before_all() -> void:
	Fixtures.use_real_content()


func after_all() -> void:
	ContentDB.use(Fixtures.content())


func test_six_events_load() -> void:
	var db := ContentDB.load_dir()
	assert_eq(db.production_events.size(), 6)
	for id: StringName in EVENT_IDS:
		assert_true(db.production_events.has(id), String(id))


func test_content_validates() -> void:
	var db := ContentDB.load_dir()
	assert_eq(db.errors, [] as Array[String])
	assert_eq(db.validate(), [] as Array[String])


func test_event_keys_have_en_and_th() -> void:
	var db := ContentDB.load_dir()
	for id: StringName in EVENT_IDS:
		var ev: ProductionEventDef = db.production_events[id]
		var keys: Array[StringName] = [ev.title_key, ev.body_key]
		keys.append_array(ev.option_keys)
		for key: StringName in keys:
			TranslationServer.set_locale("en")
			assert_ne(tr(key), String(key), String(key) + " en")
			TranslationServer.set_locale("th")
			assert_ne(tr(key), String(key), String(key) + " th")
	TranslationServer.set_locale("en")
