class_name SaveGameService
extends RefCounted

## Reads and writes the full GameState (via to_dict()/from_dict()) as JSON to
## SAVE_PATH, so an in-progress round survives an app close/kill and can be
## resumed via "Weiterspielen" (see GameScreen.resume_saved_game).

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

## True if a saved game exists ("Weiterspielen" should be offered).
static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Deletes the save file, if any (called once a round has ended).
static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
