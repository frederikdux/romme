extends Node

## App entry point. GameScreen läuft in einem CanvasLayer, damit die Controls
## ihre Anker immer gegen den echten Viewport-Rect berechnen — unabhängig davon,
## welche Auflösung oder DPI das Gerät hat.

const GameScreenScene: PackedScene = preload("res://scenes/screens/game_screen.tscn")

func _ready() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 1
	add_child(ui_layer)

	var game_screen := GameScreenScene.instantiate()
	ui_layer.add_child(game_screen)
