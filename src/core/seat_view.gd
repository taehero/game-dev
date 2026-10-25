class_name SeatView
extends RefCounted
## What one seat of the player's office shows: who sits there and which computer tier is on the desk.

var seat_index: int = 0
var desk_cell: Vector2i = Vector2i.ZERO
var staff_id: int = -1
var computer_tier: int = 0
var pose: StateQueries.StaffPose = StateQueries.StaffPose.IDLE
