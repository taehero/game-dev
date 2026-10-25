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
signal points_gained(payload: Dictionary)
signal bug_found(payload: Dictionary)
signal project_stage_changed(payload: Dictionary)
signal research_done(payload: Dictionary)
signal platform_rumored(payload: Dictionary)
signal platform_launched(payload: Dictionary)
signal platform_retired(payload: Dictionary)
signal raise_requested(payload: Dictionary)
signal staff_fired(payload: Dictionary)
signal equipment_changed(payload: Dictionary)
signal loan_taken(payload: Dictionary)
signal payment_missed(payload: Dictionary)
signal repossessed(payload: Dictionary)
signal contract_offered(payload: Dictionary)
signal contract_completed(payload: Dictionary)
signal award_result(payload: Dictionary)
signal promotion_started(payload: Dictionary)
signal game_over(payload: Dictionary)
signal game_loaded(payload: Dictionary)
signal speed_changed(payload: Dictionary)


func dispatch(event_name: StringName, payload: Dictionary) -> bool:
	if not has_signal(event_name):
		push_warning("EventBus: unknown event '%s'" % event_name)
		return false
	emit_signal(event_name, payload)
	return true
