class_name ConceptWizard
extends VBoxContainer
## Three-step new-game dialog: name/size/platform, topic/genre, engine/features.

const CARD_SCENE: PackedScene = preload("res://src/ui/panels/popup_card.tscn")
const STEP_COUNT: int = 3

var content: ContentDB

var _popup: PopupCard
var _step: int = 0
var _options: Dictionary = {}
var _pages: Array[VBoxContainer] = []
var _step_label: Label
var _title_edit: LineEdit
var _sizes: ChoiceRow
var _platforms: ChoiceRow
var _more_platforms: Label
var _topics: ChoiceRow
var _genres: ChoiceRow
var _combo: Label
var _engines: ChoiceRow
var _features: ChoiceRow
var _no_features: Label
var _tech_cap: Label
var _status: Label
var _back: Button
var _next: Button
var _create: Button


static func popup(p_content: ContentDB) -> PopupCard:
	var card: PopupCard = CARD_SCENE.instantiate()
	card.card_size = Vector2(460, 290)
	var wizard := ConceptWizard.new()
	wizard.content = p_content
	wizard._popup = card
	card.body().add_child(wizard)
	card.open(TranslationServer.translate("ui.wizard.title"))
	return card


func step() -> int:
	return _step


func next() -> void:
	if _step >= STEP_COUNT - 1 or not _step_complete():
		return
	_show_step(_step + 1)


func back() -> void:
	if _step > 0:
		_show_step(_step - 1)


func create() -> bool:
	var session: GameSession = GameRunner.session
	if session == null:
		return false
	var entry: Dictionary = _engine_entry()
	if entry.is_empty():
		return false
	var cmd: StartProjectCommand = StartProjectCommand.game(
		StateQueries.player_company_id(session.state), _title_edit.text,
		_sizes.selected(), _platforms.selected(), _topics.selected(), _genres.selected(),
		int(entry["engine_id"]), StringName(entry["licensed_id"]), _features.selected_many())
	var result: CommandResult = GameRunner.submit(cmd)
	_status.text = "" if result.ok else tr(result.reason_key)
	if result.ok:
		_popup.close()
	return result.ok


func _ready() -> void:
	var session: GameSession = GameRunner.session
	if session != null and content != null:
		_options = StateQueries.concept_options(session.state, content, session.tuning)
	_step_label = _add_label(self, "StepLabel", "SectionLabel")
	_pages.append(_build_page0())
	_pages.append(_build_page1())
	_pages.append(_build_page2())
	_status = _add_label(self, "Status", "")
	_status.add_theme_color_override(&"font_color", UiPalette.DANGER)
	var nav := HBoxContainer.new()
	add_child(nav)
	_back = _add_button(nav, "Back", "ui.wizard.back", "")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)
	_next = _add_button(nav, "Next", "ui.wizard.next", "")
	_create = _add_button(nav, "Create", "ui.wizard.create", "PrimaryButton")
	_back.pressed.connect(back)
	_next.pressed.connect(next)
	_create.pressed.connect(create)
	for row: ChoiceRow in [_sizes, _platforms, _topics, _genres]:
		row.selection_changed.connect(_on_choice_changed)
	_engines.selection_changed.connect(_on_engine_changed)
	_engines.selection_changed.connect(_on_choice_changed)
	_title_edit.text_changed.connect(_on_title_changed)
	_show_step(0)


func _build_page0() -> VBoxContainer:
	var page: VBoxContainer = _add_page()
	_add_label(page, "NameLabel", "SectionLabel").text = tr("ui.wizard.name")
	_title_edit = LineEdit.new()
	_title_edit.text = tr("ui.wizard.default_title")
	_add_unique(page, _title_edit, "TitleEdit")
	_add_label(page, "SizeLabel", "SectionLabel").text = tr("ui.wizard.size")
	_sizes = _add_row(page, "Sizes", _ids(_options.get("sizes", [])), _def_labels(content.sizes, _options.get("sizes", [])))
	_add_label(page, "PlatformLabel", "SectionLabel").text = tr("ui.wizard.platform")
	_platforms = _add_row(page, "Platforms", _ids(_options.get("platforms", [])), _def_labels(content.platforms, _options.get("platforms", [])))
	_more_platforms = _add_label(page, "MorePlatforms", "")
	_more_platforms.text = tr("ui.wizard.more_platforms")
	_more_platforms.visible = int(_options.get("kitless_on_sale", 0)) > 0
	return page


func _build_page1() -> VBoxContainer:
	var page: VBoxContainer = _add_page()
	_add_label(page, "TopicLabel", "SectionLabel").text = tr("ui.wizard.topic")
	_topics = _add_row(page, "Topics", _ids(_options.get("topics", [])), _def_labels(content.topics, _options.get("topics", [])))
	_add_label(page, "GenreLabel", "SectionLabel").text = tr("ui.wizard.genre")
	_genres = _add_row(page, "Genres", _ids(_options.get("genres", [])), _def_labels(content.genres, _options.get("genres", [])))
	_combo = _add_label(page, "Combo", "")
	return page


func _build_page2() -> VBoxContainer:
	var page: VBoxContainer = _add_page()
	_add_label(page, "EngineLabel", "SectionLabel").text = tr("ui.wizard.engine")
	var ids: Array[StringName] = []
	var labels: Array[String] = []
	for entry: Dictionary in _options.get("engines", []):
		ids.append(entry["choice_id"])
		labels.append(_engine_label(entry))
	_engines = _add_row(page, "Engines", ids, labels)
	_tech_cap = _add_label(page, "TechCap", "")
	_add_label(page, "FeatureLabel", "SectionLabel").text = tr("ui.wizard.features")
	_features = _add_row(page, "Features", [] as Array[StringName], [] as Array[String], true)
	_no_features = _add_label(page, "NoFeatures", "")
	_no_features.text = tr("ui.wizard.no_features")
	_no_features.visible = false
	return page


func _show_step(n: int) -> void:
	_step = n
	for i: int in _pages.size():
		_pages[i].visible = i == n
	_step_label.text = tr("ui.wizard.step").format({"n": n + 1, "count": STEP_COUNT})
	_back.disabled = n == 0
	_next.visible = n < STEP_COUNT - 1
	_create.visible = n == STEP_COUNT - 1
	_status.text = ""
	_update_combo()
	_update_nav()


func _step_complete() -> bool:
	match _step:
		0:
			return not _title_edit.text.strip_edges().is_empty() \
				and _sizes.selected() != &"" and _platforms.selected() != &""
		1:
			return _topics.selected() != &"" and _genres.selected() != &""
		_:
			return _engines.selected() != &""


func _update_nav() -> void:
	var done: bool = _step_complete()
	_next.disabled = not done
	_create.disabled = not done


func _update_combo() -> void:
	var session: GameSession = GameRunner.session
	if session == null or _topics.selected() == &"" or _genres.selected() == &"":
		_combo.text = ""
		return
	var key: StringName = StateQueries.combo_label_key(session.state,
		StateQueries.player_company_id(session.state), _topics.selected(), _genres.selected(), session.tuning)
	_combo.text = tr("ui.wizard.combo").format({"label": tr(key)})


func _on_choice_changed() -> void:
	_update_combo()
	_update_nav()


func _on_title_changed(_text: String) -> void:
	_update_nav()


func _on_engine_changed() -> void:
	var session: GameSession = GameRunner.session
	var entry: Dictionary = _engine_entry()
	if session == null or entry.is_empty():
		return
	var keep: Array[StringName] = _features.selected_many()
	var usable: Array[StringName] = StateQueries.usable_features(session.state, content,
		int(entry["engine_id"]), StringName(entry["licensed_id"]))
	var labels: Array[String] = []
	for f: StringName in usable:
		labels.append(tr(content.engine_features[f].name_key))
	_features.setup(usable, labels, true)
	for f: StringName in keep:
		if usable.has(f):
			_features.select(f)
	_no_features.visible = usable.is_empty()
	_tech_cap.text = tr("ui.wizard.tech_cap").format({"cap": int(entry["tech_cap"])})


func _engine_entry() -> Dictionary:
	var chosen: StringName = _engines.selected()
	for entry: Dictionary in _options.get("engines", []):
		if entry["choice_id"] == chosen:
			return entry
	return {}


func _engine_label(entry: Dictionary) -> String:
	if StringName(entry["name_key"]) != &"":
		return tr(StringName(entry["name_key"]))
	return String(entry["name"])


func _ids(src: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: Variant in src:
		out.append(StringName(id))
	return out


func _def_labels(defs: Dictionary, src: Array) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in src:
		out.append(tr(defs[StringName(id)].name_key))
	return out


func _add_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	add_child(page)
	return page


func _add_unique(parent: Node, node: Node, node_name: String) -> void:
	node.name = node_name
	parent.add_child(node)
	node.owner = self
	node.unique_name_in_owner = true


func _add_label(parent: Node, node_name: String, variation: String) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 120.0
	if not variation.is_empty():
		label.theme_type_variation = StringName(variation)
	_add_unique(parent, label, node_name)
	return label


func _add_row(parent: Node, node_name: String, ids: Array[StringName], labels: Array[String], multi: bool = false) -> ChoiceRow:
	var row := ChoiceRow.new()
	row.setup(ids, labels, multi)
	_add_unique(parent, row, node_name)
	return row


func _add_button(parent: Node, node_name: String, key: String, variation: String) -> Button:
	var b := Button.new()
	b.text = tr(key)
	if not variation.is_empty():
		b.theme_type_variation = StringName(variation)
	_add_unique(parent, b, node_name)
	return b
