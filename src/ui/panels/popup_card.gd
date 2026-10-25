class_name PopupCard
extends Control
## Modal popup base: dimmed backdrop plus a centred card. Content goes in body().

signal closed

@export var card_size: Vector2 = Vector2(400, 200)
@export var closable: bool = true


func _ready() -> void:
	var backdrop: ColorRect = get_node("Backdrop") as ColorRect
	backdrop.color = UiPalette.BACKDROP
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	var close_btn: Button = get_node("%Close") as Button
	close_btn.icon = UiIcons.texture(&"close")
	close_btn.tooltip_text = tr("ui.popup.close")
	close_btn.visible = closable
	close_btn.pressed.connect(close)
	resized.connect(_centre)


func open(title: String) -> void:
	(get_node("%Title") as Label).text = title
	var card: Control = get_node("%Card") as Control
	card.size = card_size
	card.visible = true
	_centre()


func body() -> VBoxContainer:
	return get_node("%Body") as VBoxContainer


func close() -> void:
	closed.emit()
	queue_free()


func _centre() -> void:
	var card: Control = get_node("%Card") as Control
	card.size = card_size
	card.position = ((size - card_size) / 2.0).round()
