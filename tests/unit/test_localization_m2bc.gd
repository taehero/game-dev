extends GutTest
## Every M2bc key in locale/strings.csv has an en and a th value, and format params survive in th.

const KEYS: Array[String] = [
	"ui.gameover.title",
	"ui.gameover.reason",
	"ui.gameover.cash",
	"ui.gameover.games",
	"ui.gameover.new_game",
	"ui.gameover.load",
	"ui.gameover.no_save",
	"ui.level.junior",
	"ui.level.mid",
	"ui.level.senior",
	"ui.level.lead",
	"ui.loan.section",
	"ui.loan.rate",
	"ui.loan.credit",
	"ui.loan.refused",
	"ui.loan.shark_warning",
	"ui.loan.take",
	"ui.loan.list",
	"ui.loan.none",
	"ui.loan.balance",
	"ui.loan.payment",
	"ui.loan.missed",
	"ui.loan.repay",
	"ui.loan.repay_all",
	"ui.contract.section",
	"ui.contract.pay",
	"ui.contract.deadline",
	"ui.contract.expires",
	"ui.contract.uses_staff",
	"ui.contract.accept",
	"ui.contract.running",
	"ui.contract.none",
	"ui.costs.section",
	"ui.costs.rent",
	"ui.costs.electricity",
	"ui.costs.leases",
	"ui.costs.total",
	"ui.team.fire",
	"ui.team.fire_confirm",
	"ui.team.cancel",
	"ui.team.asks",
	"ui.team.asks_promotion",
	"ui.candidates.section",
	"ui.candidates.none",
	"ui.candidates.asking",
	"ui.candidates.expires",
	"ui.owner.section",
	"ui.owner.points",
	"ui.owner.xp",
	"ui.owner.focus",
	"ui.owner.focus_hint",
	"ui.owner.path.dev",
	"ui.owner.path.business",
	"ui.owner.rank",
	"ui.owner.learn",
	"ui.ask.title_raise",
	"ui.ask.title_promotion",
	"ui.ask.body_raise",
	"ui.ask.body_promotion",
	"ui.ask.refuse_hint",
	"ui.ask.deadline",
	"ui.ask.gone",
	"ui.seats.section",
	"ui.seats.leased",
	"ui.seats.outdated",
	"ui.seats.buy",
	"ui.seats.lease",
	"ui.seats.sell",
	"ui.seats.return",
	"ui.seats.seating",
	"ui.seats.no_desk",
	"ui.seats.assign",
	"ui.office.section",
	"ui.office.current",
	"ui.office.now",
	"ui.office.seats",
	"ui.office.rent",
	"ui.office.power",
	"ui.office.after",
	"ui.office.move",
	"ui.license.section",
	"ui.license.fee",
	"ui.license.royalty",
	"ui.license.sign",
	"ui.license.signed",
	"ui.license.none",
	"ui.marketing.section",
	"ui.marketing.for",
	"ui.marketing.no_project",
	"ui.marketing.cost",
	"ui.marketing.hype",
	"ui.marketing.run",
	"ui.segment.core",
	"ui.segment.casual",
	"ui.promo.section",
	"ui.promo.none",
	"ui.promo.discount",
	"ui.promo.weeks",
	"ui.promo.start",
	"ui.promo.active",
	"ui.promo.fatigue",
	"ui.award.section",
	"ui.award.ceremony",
	"ui.award.fee",
	"ui.award.prize",
	"ui.award.enter",
	"ui.award.entered",
	"ui.award.won",
	"ui.award.none",
	"ui.live.title",
	"ui.live.stats",
	"ui.live.free_workers",
	"ui.live.task_patch",
	"ui.live.task_mod",
	"ui.live.patch",
	"ui.live.patch_hint",
	"ui.live.mod_tools",
	"ui.live.mod_done",
	"ui.live.mod_hint",
	"ui.live.dlc_title",
	"ui.live.dlc_default",
	"ui.live.dlc",
	"ui.live.dlc_count",
	"ui.live.not_live",
	"ui.forum.title",
	"ui.forum.none",
	"ui.forum.ago",
	"ui.forum.mood",
	"ui.forum.replied",
	"ui.project.manage",
	"ui.project.forum"
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
