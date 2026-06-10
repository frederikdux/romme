class_name SaveGameService
extends RefCounted

## Placeholder for future save/load support. Not wired into the UI yet —
## GameState already exposes to_dict()/from_dict() so this just needs to
## read/write that dictionary as JSON when persistence becomes a priority.

const SAVE_PATH := "user://savegame.json"

static func save(game_state: GameState) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveGameService: could not open '%s' for writing." % SAVE_PATH)
		return
	file.store_string(JSON.stringify(game_state.to_dict()))

static func load_into(game_state: GameState) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveGameService: could not open '%s' for reading." % SAVE_PATH)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveGameService: save file '%s' is not valid." % SAVE_PATH)
		return false
	game_state.from_dict(parsed)
	return true
