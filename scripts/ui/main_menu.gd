extends Control

## Entry screen shown on app start and after a round ends. Lets the player
## start a new game, resume a saved one (if any), or open settings.

signal new_game_requested
signal continue_requested
signal settings_requested

const MENU_BACKGROUND_PATH := "res://assets/images/menu_background.png"
const VERSION_TEXT := "Version 0.1.0"

const COLOR_ACCENT_BLUE := Color(0.129, 0.588, 0.953) # #2196F3
const COLOR_GREEN := Color(0.298, 0.686, 0.314) # #4CAF50
const COLOR_GREY_NEUTRAL := Color(0.45, 0.45, 0.45)

const CardViewScene: PackedScene = preload("res://scenes/components/card_view.tscn")

## Size of each decorative card in the main menu's card fan.
const FAN_CARD_SIZE := Vector2(120, 168)
## (suit, rank, x offset of pivot from center, rotation in degrees) for each
## of the 4 fanned-out cards, left to right: Herz-As, Pik-König, Karo-Dame,
## Kreuz-Bube.
const FAN_CARDS := [
	{"suit": Card.Suit.HEARTS, "rank": 1, "dx": -90.0, "rotation": -18.0},
	{"suit": Card.Suit.SPADES, "rank": 13, "dx": -30.0, "rotation": -6.0},
	{"suit": Card.Suit.DIAMONDS, "rank": 12, "dx": 30.0, "rotation": 6.0},
	{"suit": Card.Suit.CLUBS, "rank": 11, "dx": 90.0, "rotation": 18.0},
]

var background_texture: TextureRect
var card_fan_container: Control
var new_game_button: Button
var continue_button: Button
var settings_button: Button
var version_label: Label

func _ready() -> void:
	background_texture = _require_node("BackgroundTexture") as TextureRect
	card_fan_container = _require_node("CardFanContainer") as Control
	new_game_button = _require_node("NewGameButton") as Button
	continue_button = _require_node("ContinueButton") as Button
	settings_button = _require_node("SettingsButton") as Button
	version_label = _require_node("VersionLabel") as Label

	if ResourceLoader.exists(MENU_BACKGROUND_PATH):
		background_texture.texture = load(MENU_BACKGROUND_PATH)

	version_label.text = VERSION_TEXT

	new_game_button.pressed.connect(func() -> void: new_game_requested.emit())
	continue_button.pressed.connect(func() -> void: continue_requested.emit())
	settings_button.pressed.connect(func() -> void: settings_requested.emit())

	_style_button(new_game_button, COLOR_GREEN)
	_style_button(continue_button, COLOR_ACCENT_BLUE)
	_style_button(settings_button, COLOR_GREY_NEUTRAL)

	var has_save := SaveGameService.has_save()
	continue_button.disabled = not has_save
	if not has_save:
		continue_button.tooltip_text = "Kein gespeichertes Spiel"

	_build_card_fan()

## Builds the decorative, non-interactive fan of 4 playing cards shown between
## the title and the buttons. Each card is anchored to the center of
## CardFanContainer (anchors all 0.5) and positioned/rotated via offsets and
## pivot_offset, so the layout doesn't depend on the container's final size.
func _build_card_fan() -> void:
	for fan_card in FAN_CARDS:
		var card_view := CardViewScene.instantiate() as CardView
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_view.disabled = true
		card_view.set_anchors_preset(Control.PRESET_CENTER)
		var dx: float = fan_card["dx"]
		card_view.offset_left = -FAN_CARD_SIZE.x * 0.5 + dx
		card_view.offset_top = -FAN_CARD_SIZE.y
		card_view.offset_right = card_view.offset_left + FAN_CARD_SIZE.x
		card_view.offset_bottom = card_view.offset_top + FAN_CARD_SIZE.y
		card_view.pivot_offset = Vector2(FAN_CARD_SIZE.x * 0.5, FAN_CARD_SIZE.y)
		card_view.rotation_degrees = fan_card["rotation"]
		card_fan_container.add_child(card_view)
		card_view.setup(Card.new(fan_card["suit"], fan_card["rank"]), -1)

## Finds a required child node by name or fails loudly.
func _require_node(node_name: String) -> Node:
	var node := find_child(node_name, true, false)
	if node == null:
		var message := "MainMenu is missing the required node '%s'. Add it to main_menu.tscn." % node_name
		push_error(message)
		assert(false, message)
	return node

func _style_button(button: Button, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", style)

	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = color.lightened(0.15)
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style: StyleBoxFlat = style.duplicate()
	pressed_style.bg_color = color.darkened(0.15)
	button.add_theme_stylebox_override("pressed", pressed_style)

	var disabled_style: StyleBoxFlat = style.duplicate()
	disabled_style.bg_color = color.darkened(0.25)
	button.add_theme_stylebox_override("disabled", disabled_style)
