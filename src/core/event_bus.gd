extends Node
## Autoload "EventBus". No class_name: it would hide the autoload.

signal week_ticked(payload: Dictionary)
signal era_changed(payload: Dictionary)
signal money_changed(payload: Dictionary)
signal project_changed(payload: Dictionary)
signal project_phase_changed(payload: Dictionary)
signal decision_required(payload: Dictionary)
signal review_published(payload: Dictionary)
signal sales_updated(payload: Dictionary)
signal staff_hired(payload: Dictionary)
signal staff_resigned(payload: Dictionary)
signal forum_post_created(payload: Dictionary)
signal command_rejected(payload: Dictionary)


func dispatch(event_name: StringName, payload: Dictionary) -> bool:
	if not has_signal(event_name):
		push_warning("EventBus: unknown event '%s'" % event_name)
		return false
	emit_signal(event_name, payload)
	return true
