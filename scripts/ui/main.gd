extends Node

## App entry point. Screens (MainMenu, GameScreen) run in a CanvasLayer, damit
## die Controls ihre Anker immer gegen den echten Viewport-Rect berechnen —
## unabhängig davon, welche Auflösung oder DPI das Gerät hat. Switches between
## MainMenu and GameScreen based on the signals each screen emits.

const MainMenuScene: PackedScene = preload("res://scenes/screens/main_menu.tscn")
const GameScreenScene: PackedScene = preload("res://scenes/screens/game_screen.tscn")

var _ui_layer: CanvasLayer
var _current_screen: Node

func _ready() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 1
	add_child(_ui_layer)
	_show_main_menu()

func _show_main_menu() -> void:
	var menu = MainMenuScene.instantiate()
	_set_screen(menu)
	menu.new_game_requested.connect(_on_new_game_requested)
	menu.continue_requested.connect(_on_continue_requested)
	menu.settings_requested.connect(_on_settings_requested)

func _on_new_game_requested() -> void:
	var screen = GameScreenScene.instantiate()
	_set_screen(screen)
	screen.return_to_main_menu.connect(_show_main_menu)
	screen.start_new_game()

func _on_continue_requested() -> void:
	var screen = GameScreenScene.instantiate()
	_set_screen(screen)
	screen.return_to_main_menu.connect(_show_main_menu)
	screen.resume_saved_game()

func _on_settings_requested() -> void:
	var screen = GameScreenScene.instantiate()
	_set_screen(screen)
	screen.return_to_main_menu.connect(_show_main_menu)
	screen.show_settings()

func _set_screen(screen: Node) -> void:
	if is_instance_valid(_current_screen):
		_current_screen.queue_free()
	_current_screen = screen
	_ui_layer.add_child(screen)
