class_name EnginePopup
extends VBoxContainer
## Dialog that starts an ENGINE project from the researched engine features.

const CARD_SCENE: PackedScene = preload("res://src/ui/panels/popup_card.tscn")

var content: ContentDB

var _popup: PopupCard
var _title_edit: LineEdit
var _features: ChoiceRow
var _create: Button
var _status: Label


static func popup(p_content: ContentDB) -> PopupCard:
	var card: PopupCard = CARD_SCENE.instantiate()
	card.card_size = Vector2(360, 240)
	var dialog := EnginePopup.new()
	dialog.content = p_content
	dialog._popup = card
	card.body().add_child(dialog)
	card.open(TranslationServer.translate("ui.engine.title"))
	return card


func create() -> bool:
	var session: GameSession = GameRunner.session
	if session == null:
		return false
	var cmd: StartProjectCommand = StartProjectCommand.engine(
		StateQueries.player_company_id(session.state), _title_edit.text, _features.selected_many())
	var result: CommandResult = GameRunner.submit(cmd)
	_status.text = "" if result.ok else tr(result.reason_key)
	if result.ok:
		_popup.close()
	return result.ok


func _ready() -> void:
	var session: GameSession = GameRunner.session
	var ids: Array[StringName] = []
	var labels: Array[String] = []
	if session != null and content != null:
		ids = StateQueries.engine_feature_options(session.state, content)
		for id: StringName in ids:
			var def: EngineFeatureDef = content.engine_features[id]
			labels.append(tr(def.name_key) + " · " + tr("ui.engine.weeks").format({"weeks": def.dev_weeks}))
	_title_edit = LineEdit.new()
	_title_edit.text = tr("ui.engine.default_title")
	_add_unique(_title_edit, "TitleEdit")
	var heading := Label.new()
	heading.text = tr("ui.engine.features")
	heading.theme_type_variation = &"SectionLabel"
	add_child(heading)
	_features = ChoiceRow.new()
	_features.setup(ids, labels, true)
	_add_unique(_features, "Features")
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 120.0
	_status.add_theme_color_override(&"font_color", UiPalette.DANGER)
	_add_unique(_status, "Status")
	_create = Button.new()
	_create.text = tr("ui.engine.create")
	_create.theme_type_variation = &"PrimaryButton"
	_add_unique(_create, "Create")
	_create.pressed.connect(create)
	_features.selection_changed.connect(_update)
	_title_edit.text_changed.connect(_update_text)
	_update()


func _update_text(_text: String) -> void:
	_update()


func _update() -> void:
	_create.disabled = _features.selected_many().is_empty() or _title_edit.text.strip_edges().is_empty()


func _add_unique(node: Node, node_name: String) -> void:
	node.name = node_name
	add_child(node)
	node.owner = self
	node.unique_name_in_owner = true
