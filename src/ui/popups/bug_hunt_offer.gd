class_name BugHuntOffer
extends VBoxContainer
## Offer to play the bug-hunt mini-game for a project that reached polish.

signal hunt_requested(project_id: int)

const CARD_SCENE: PackedScene = preload("res://src/ui/panels/popup_card.tscn")

var project_id: int = -1
var tuning: TuningDef

var _popup: PopupCard


static func popup(p_project_id: int, p_tuning: TuningDef) -> PopupCard:
	var card: PopupCard = CARD_SCENE.instantiate()
	card.card_size = Vector2(340, 170)
	var dialog := BugHuntOffer.new()
	dialog.project_id = p_project_id
	dialog.tuning = p_tuning
	dialog._popup = card
	card.body().add_child(dialog)
	card.open(TranslationServer.translate("ui.bughunt.offer_title"))
	return card


func _ready() -> void:
	var body := Label.new()
	body.text = tr("ui.bughunt.offer_body").format({
		"seconds": int(tuning.bug_hunt_seconds), "cap": tuning.bug_hunt_max_bugs})
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 120.0
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_add_unique(body, "Body")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 8)
	add_child(row)
	var start := Button.new()
	start.text = tr("ui.bughunt.start")
	start.theme_type_variation = &"PrimaryButton"
	start.pressed.connect(_on_start)
	_add_unique(start, "Start", row)
	var skip := Button.new()
	skip.text = tr("ui.bughunt.skip")
	skip.pressed.connect(_popup.close)
	_add_unique(skip, "Skip", row)


func _on_start() -> void:
	hunt_requested.emit(project_id)
	_popup.close()


func _add_unique(node: Node, node_name: String, parent: Node = self) -> void:
	node.name = node_name
	parent.add_child(node)
	node.owner = self
	node.unique_name_in_owner = true
