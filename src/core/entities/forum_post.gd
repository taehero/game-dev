class_name ForumPost
extends RefCounted

const SCHEMA: Dictionary = {
	"id": "int",
	"project_id": "int",
	"week": "int",
	"topic_key": "string",
	"sentiment": "int",
	"replied": "bool",
}

var id: int
var project_id: int
var week: int
var topic_key: StringName
var sentiment: int
var replied: bool = false


func to_dict() -> Dictionary:
	return {
		"id": id,
		"project_id": project_id,
		"week": week,
		"topic_key": String(topic_key),
		"sentiment": sentiment,
		"replied": replied,
	}


static func from_dict(d: Dictionary) -> ForumPost:
	var f := ForumPost.new()
	f.id = int(d["id"])
	f.project_id = int(d["project_id"])
	f.week = int(d["week"])
	f.topic_key = StringName(String(d["topic_key"]))
	f.sentiment = int(d["sentiment"])
	f.replied = bool(d["replied"])
	return f
