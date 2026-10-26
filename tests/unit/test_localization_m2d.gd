extends GutTest
## Every M2d key in locale/strings.csv has an en and a th value, and format params survive in th.

const KEYS: Array[String] = [
	"ui.project.none",
	"ui.project.new_game",
	"ui.project.new_engine",
	"ui.project.release",
	"ui.project.bug_hunt",
	"ui.project.focus",
	"ui.project.stage_name",
	"ui.project.past_games",
	"ui.project.no_past_games",
	"ui.project.details",
	"ui.project.units",
	"ui.project.engine_building",
	"ui.phase.production",
	"ui.phase.polish",
	"ui.phase.released",
	"ui.phase.live",
	"ui.phase.retired",
	"ui.slider.code",
	"ui.slider.design",
	"ui.slider.story",
	"ui.slider.levels",
	"ui.slider.characters",
	"ui.slider.ai",
	"ui.slider.graphics",
	"ui.slider.audio",
	"ui.slider.balance",
	"ui.team.owner",
	"ui.team.no_computer",
	"ui.team.skill_tree_soon",
	"ui.team.hire",
	"ui.team.hire_name",
	"ui.team.salary",
	"ui.team.morale",
	"ui.team.free_seats",
	"ui.equipment.dev_kits",
	"ui.equipment.buy_kit",
	"ui.equipment.owned",
	"ui.equipment.platforms_owned",
	"ui.equipment.desks",
	"ui.equipment.desk",
	"ui.equipment.computer",
	"ui.equipment.empty",
	"ui.equipment.buy_soon",
	"ui.finance.cash",
	"ui.finance.salaries",
	"ui.finance.total_revenue",
	"ui.finance.by_game",
	"ui.finance.none",
	"ui.market.platforms",
	"ui.market.status.unannounced",
	"ui.market.status.rumored",
	"ui.market.status.on_sale",
	"ui.market.status.retired",
	"ui.market.install_base",
	"ui.market.research",
	"ui.market.rp",
	"ui.market.research_cost",
	"ui.market.research_buy",
	"ui.market.done",
	"ui.market.needs",
	"ui.wizard.title",
	"ui.wizard.step",
	"ui.wizard.name",
	"ui.wizard.default_title",
	"ui.wizard.size",
	"ui.wizard.platform",
	"ui.wizard.topic",
	"ui.wizard.genre",
	"ui.wizard.engine",
	"ui.wizard.features",
	"ui.wizard.combo",
	"ui.wizard.more_platforms",
	"ui.wizard.no_features",
	"ui.wizard.tech_cap",
	"ui.wizard.back",
	"ui.wizard.next",
	"ui.wizard.create",
	"ui.engine.title",
	"ui.engine.default_title",
	"ui.engine.features",
	"ui.engine.weeks",
	"ui.engine.create",
	"ui.review.title",
	"ui.review.average",
	"ui.review.strength",
	"ui.review.weakness",
	"ui.sales.title",
	"ui.sales.total",
	"ui.sales.no_data",
	"ui.sales.weeks",
	"ui.event.project",
	"ui.effect.design",
	"ui.effect.tech",
	"ui.effect.art",
	"ui.effect.audio",
	"ui.effect.bugs",
	"ui.effect.hype",
	"ui.effect.morale",
	"ui.effect.progress_bp",
	"ui.effect.none",
	"ui.bughunt.offer_title",
	"ui.bughunt.offer_body",
	"ui.bughunt.start",
	"ui.bughunt.skip",
	"ui.bughunt.title",
	"ui.bughunt.time",
	"ui.bughunt.caught",
	"ui.bughunt.result",
	"ui.popup.ok",
	"error.decision_not_found",
	"error.decision_not_event",
	"error.invalid_option",
	"error.project_not_polishing",
	"error.bug_hunt_done",
	"error.invalid_amount",
	"event.big_bug.title",
	"event.big_bug.body",
	"event.big_bug.option.1",
	"event.big_bug.option.2",
	"event.bold_idea.title",
	"event.bold_idea.body",
	"event.bold_idea.option.1",
	"event.bold_idea.option.2",
	"event.bold_idea.option.3",
	"event.magazine_preview.title",
	"event.magazine_preview.body",
	"event.magazine_preview.option.1",
	"event.magazine_preview.option.2",
	"event.power_cut.title",
	"event.power_cut.body",
	"event.power_cut.option.1",
	"event.power_cut.option.2",
	"event.sound_trick.title",
	"event.sound_trick.body",
	"event.sound_trick.option.1",
	"event.sound_trick.option.2",
	"event.late_night.title",
	"event.late_night.body",
	"event.late_night.option.1",
	"event.late_night.option.2"
]

func after_each() -> void:
	TranslationServer.set_locale("en")


func test_m2d_keys_have_en_and_th() -> void:
	for key: String in KEYS:
		TranslationServer.set_locale("en")
		assert_ne(tr(key), key, "missing en: " + key)
		TranslationServer.set_locale("th")
		assert_ne(tr(key), key, "missing th: " + key)


func test_format_params_survive_in_th() -> void:
	var re := RegEx.new()
	re.compile("\\{[a-z_]+\\}")
	for key: String in KEYS:
		TranslationServer.set_locale("en")
		var en_text := tr(key)
		if not en_text.contains("{"):
			continue
		TranslationServer.set_locale("th")
		var th_text := tr(key)
		var en_tokens: Array[String] = []
		for m: RegExMatch in re.search_all(en_text):
			en_tokens.append(m.get_string())
		var th_tokens: Array[String] = []
		for m: RegExMatch in re.search_all(th_text):
			th_tokens.append(m.get_string())
		en_tokens.sort()
		th_tokens.sort()
		assert_eq(th_tokens, en_tokens, key)
