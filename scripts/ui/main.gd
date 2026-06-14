extends Node

## App entry point. Screens (MainMenu, GameSetupScreen, GameScreen,
## SettingsScreen) run in a CanvasLayer, damit die Controls ihre Anker immer
## gegen den echten Viewport-Rect berechnen — unabhängig davon, welche
## Auflösung oder DPI das Gerät hat. Switches between screens based on the
## signals each screen emits.

const MainMenuScene: PackedScene = preload("res://scenes/screens/main_menu.tscn")
const GameSetupScreenScene: PackedScene = preload("res://scenes/screens/game_setup_screen.tscn")
const GameScreenScene: PackedScene = preload("res://scenes/screens/game_screen.tscn")
const SettingsScreenScene: PackedScene = preload("res://scenes/screens/settings_screen.tscn")

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
	menu.new_game_requested.connect(_show_game_setup)
	menu.continue_requested.connect(_on_continue_requested)
	menu.settings_requested.connect(_show_settings)

func _show_game_setup() -> void:
	var screen = GameSetupScreenScene.instantiate()
	_set_screen(screen)
	screen.back_requested.connect(_show_main_menu)
	screen.start_game_requested.connect(_on_start_game_requested)

func _on_start_game_requested(opponent_count: int) -> void:
	var screen = GameScreenScene.instantiate()
	_set_screen(screen)
	screen.return_to_main_menu.connect(_show_main_menu)
	screen.new_game_requested.connect(_show_game_setup)
	screen.start_new_game(opponent_count)

func _on_continue_requested() -> void:
	var screen = GameScreenScene.instantiate()
	_set_screen(screen)
	screen.return_to_main_menu.connect(_show_main_menu)
	screen.new_game_requested.connect(_show_game_setup)
	screen.resume_saved_game()

func _show_settings() -> void:
	var screen = SettingsScreenScene.instantiate()
	_set_screen(screen)
	screen.back_requested.connect(_show_main_menu)

func _set_screen(screen: Node) -> void:
	if is_instance_valid(_current_screen):
		_current_screen.queue_free()
	_current_screen = screen
	_ui_layer.add_child(screen)
