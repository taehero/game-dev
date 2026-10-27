extends GutTest

const KEYS: Array[String] = [
	"content.channel.magazine_ad.name", "content.channel.mail_order.name",
	"content.channel.trade_show.name", "content.channel.tv_spot.name",
	"content.research.tv_advertising.name", "content.award.golden_cartridge.name",
	"content.size.dlc.name", "forum.post.bugs", "forum.post.weakness", "forum.post.mod_viral",
	"forum.reply.apologise", "forum.reply.promise_patch", "forum.reply.ignore",
	"error.channel_not_found", "error.channel_unavailable", "error.project_not_marketable",
	"error.project_not_live", "error.promo_active", "error.invalid_discount",
	"error.invalid_promo_weeks", "error.live_task_running", "error.no_bugs",
	"error.mod_tools_built", "error.dlc_of_dlc", "error.dlc_in_progress", "error.size_dlc_only",
	"error.post_not_found", "error.post_replied", "error.invalid_reply", "error.no_patch_running",
	"error.award_not_found", "error.award_entered", "error.award_not_eligible"]


func after_each() -> void:
	TranslationServer.set_locale("en")


func test_every_m2c_key_has_en_and_th() -> void:
	for key: String in KEYS:
		for loc: String in ["en", "th"]:
			TranslationServer.set_locale(loc)
			var s := tr(key)
			assert_true(s != "" and s != key, "%s missing in %s" % [key, loc])
