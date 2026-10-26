class_name EventView
extends VBoxContainer
## Production event popup: project, body text and one button per option with its effects.

const CARD_SCENE: PackedScene = preload("res://src/ui/panels/popup_card.tscn")
const OPTION_FONT_SIZE: int = 10

var decision_id: int = -1

var _popup: PopupCard
var _info: Dictionary = {}


static func popup(p_decision_id: int, content: ContentDB) -> PopupCard:
	var card: PopupCard = CARD_SCENE.instantiate()
	card.card_size = Vector2(380, 230)
	var dialog := EventView.new()
	dialog.decision_id = p_decision_id
	dialog._popup = card
	if GameRunner.session != null:
		dialog._info = StateQueries.event_view(GameRunner.session.state, content, p_decision_id)
	# Modal while the decision is valid; an empty info (decision gone) has no buttons, so it needs a close.
	card.closable = dialog._info.is_empty()
	card.body().add_child(dialog)
	card.open(TranslationServer.translate(String(dialog._info.get("title_key", &"ui.event.title"))))
	return card


func choose(index: int) -> bool:
	if GameRunner.session == null:
		return false
	var result: CommandResult = GameRunner.submit(ChooseEventOptionCommand.new(decision_id, index))
	# Success or refusal both leave the popup: a refused decision is gone and cannot be answered.
	_popup.close()
	return result.ok


func _ready() -> void:
	add_theme_constant_override(&"separation", 2)
	var project := Label.new()
	project.text = tr("ui.event.project").format({"title": String(_info.get("project_title", ""))})
	project.theme_type_variation = &"SectionLabel"
	project.clip_text = true
	project.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_add_unique(project, "Project")
	var body := Label.new()
	body.text = tr(String(_info.get("body_key", &"")))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 120.0
	body.add_theme_font_size_override(&"font_size", 11)
	_add_unique(body, "Body")
	var keys: Array = _info.get("option_keys", [])
	var effects: Array = _info.get("effects", [])
	for i: int in keys.size():
		var fx: Dictionary = effects[i] if i < effects.size() else {}
		var button := Button.new()
		button.text = tr(String(keys[i])) + "\n" + _effect_text(fx)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = false
		button.custom_minimum_size.x = 120.0
		button.add_theme_font_size_override(&"font_size", OPTION_FONT_SIZE)
		for style_name: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			var base: StyleBox = button.get_theme_stylebox(style_name)
			if base != null:
				var tight: StyleBox = base.duplicate()
				tight.content_margin_top = 2.0
				tight.content_margin_bottom = 2.0
				button.add_theme_stylebox_override(style_name, tight)
		button.pressed.connect(choose.bind(i))
		button.name = "Option_%d" % i
		add_child(button)


func _effect_text(fx: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: StringName in ProductionEventDef.EFFECTS:
		var v: int = int(fx.get(k, 0))
		if v == 0:
			continue
		@warning_ignore("integer_division")
		var shown: int = v / 100 if k == &"progress_bp" else v
		parts.append(tr("ui.effect." + String(k)).format({"n": UiFormat.signed(shown)}))
	return ", ".join(parts) if not parts.is_empty() else tr("ui.effect.none")


func _add_unique(node: Node, node_name: String) -> void:
	node.name = node_name
	add_child(node)
	node.owner = self
	node.unique_name_in_owner = true
