class_name SalesView
extends VBoxContainer
## Sales popup content: totals, weekly average and a bar graph of the latest weeks.

const POPUP_SCENE: PackedScene = preload("res://src/ui/panels/popup_card.tscn")
const CARD_SIZE := Vector2(420, 250)
const MAX_WEEKS: int = 26


static func popup(project_id: int, _content: ContentDB) -> PopupCard:
	var card: PopupCard = POPUP_SCENE.instantiate() as PopupCard
	card.card_size = CARD_SIZE
	var view := SalesView.new()
	view._build(card, project_id)
	card.body().add_child(view)
	return card


@warning_ignore("integer_division")
func _build(card: PopupCard, project_id: int) -> void:
	var title: String = ""
	var units_sold: int = 0
	var revenue: int = 0
	var series: Array[int] = []
	if GameRunner.session != null:
		var view: GameState = GameRunner.session.state
		series = StateQueries.sales_series(view, project_id)
		for g: Dictionary in StateQueries.past_games(view):
			if g["id"] == project_id:
				title = g["title"]
				units_sold = g["units_sold"]
				revenue = g["revenue"]
		if title == "" and view.projects.has(project_id):
			title = view.projects[project_id].title
	card.open(tr("ui.sales.title") + ": " + title)
	var shown: Array[int] = series.slice(maxi(series.size() - MAX_WEEKS, 0))
	var totals := Label.new()
	totals.text = tr("ui.sales.total").format({"units": UiFormat.thousands(units_sold), "money": UiFormat.money(revenue)})
	totals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	totals.custom_minimum_size = Vector2(380, 0)
	_own(totals, "Totals")
	if shown.is_empty():
		var none := Label.new()
		none.text = tr("ui.sales.no_data")
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.size_flags_vertical = Control.SIZE_EXPAND_FILL
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_own(none, "NoData")
	else:
		var average := Label.new()
		average.text = tr("ui.sales.average").format({"units": UiFormat.thousands(units_sold / series.size())})
		_own(average, "Average")
		var graph := SalesGraph.new()
		_own(graph, "Graph")
		graph.set_series(shown)
		var weeks := Label.new()
		weeks.text = tr("ui.sales.weeks").format({"n": shown.size()})
		weeks.theme_type_variation = &"SectionLabel"
		weeks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_own(weeks, "Weeks")
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
