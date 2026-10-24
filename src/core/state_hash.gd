class_name StateHash
extends RefCounted


static func of(state: GameState) -> String:
	return JSON.stringify(state.to_dict(), "", true, true).sha256_text()
