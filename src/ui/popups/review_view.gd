class_name ReviewView
extends VBoxContainer
## Review popup content: average score plus one card per outlet (direction C).

const POPUP_SCENE: PackedScene = preload("res://src/ui/panels/popup_card.tscn")
const CARD_SIZE := Vector2(540, 290)
const TEXT_SIZE: int = 10


static func popup(project_id: int, content: ContentDB) -> PopupCard:
	var card: PopupCard = POPUP_SCENE.instantiate() as PopupCard
	card.card_size = CARD_SIZE
	var view := ReviewView.new()
	view._build(card, project_id, content)
	card.body().add_child(view)
	return card


func _build(card: PopupCard, project_id: int, content: ContentDB) -> void:
	var info: Dictionary = {}
	if GameRunner.session != null:
		info = StateQueries.review_view(GameRunner.session.state, project_id)
	card.open(tr("ui.review.title") + ": " + String(info.get("title", "")))
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var average := Label.new()
	average.text = tr("ui.review.average").format({"score": UiFormat.score(int(info.get("user_score", 0)))})
	average.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	average.theme_type_variation = &"CardTitle"
	_own(average, "Average")
	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override(&"separation", 6)
	_own(cards, "Cards")
	var genre_id: StringName = info.get("genre_id", &"")
	var platform_id: StringName = info.get("platform_id", &"")
	var vars: Dictionary = {
		"genre": tr(content.genres[genre_id].name_key) if content.genres.has(genre_id) else "",
		"platform": tr(content.platforms[platform_id].name_key) if content.platforms.has(platform_id) else "",
	}
	var reviews: Array = info.get("reviews", [])
	for entry: Variant in reviews:
		var r: Dictionary = entry
		cards.add_child(_outlet_card(r, content, vars))
	var ok := Button.new()
	ok.text = tr("ui.popup.ok")
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(card.close)
	_own(ok, "Ok")


func _own(node: Control, node_name: String) -> void:
	node.name = node_name
	add_child(node)
	node.owner = self
	node.unique_name_in_owner = true


func _outlet_card(r: Dictionary, content: ContentDB, vars: Dictionary) -> PanelContainer:
	var outlet_id: StringName = r["outlet_id"]
	var panel := PanelContainer.new()
	panel.name = "Outlet_%s" % outlet_id
	panel.theme_type_variation = &"RowPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.custom_minimum_size = Vector2(0, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	panel.add_child(col)
	var title := Label.new()
	title.name = "Name"
	title.text = tr(content.outlets[outlet_id].name_key) if content.outlets.has(outlet_id) else String(outlet_id)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 11)
	col.add_child(title)
	var ring := ScoreRing.new()
	ring.name = "Ring"
	ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ring.set_score(int(r["score_x10"]))
	col.add_child(ring)
	col.add_child(_section(tr("ui.review.strength"), "LikedLabel"))
	col.add_child(_reason(r["strength_key"], vars, "Liked"))
	col.add_child(_section(tr("ui.review.weakness"), "DislikedLabel"))
	col.add_child(_reason(r["weakness_key"], vars, "Disliked"))
	return panel


func _section(text: String, node_name: String) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = text
	l.theme_type_variation = &"SectionLabel"
	return l


func _reason(key: StringName, vars: Dictionary, node_name: String) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = tr(key).format(vars) if key != &"" else ""
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(96, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override(&"font_size", TEXT_SIZE)
	return l
