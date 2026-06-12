class_name CardView
extends Button

## Visual representation of a single playing card: cream background, rank +
## suit symbol in the top-left and (rotated 180°) bottom-right corners, and a
## big suit symbol in the center. Emits card_toggled on tap, and
## drag_started/card_dragged/drag_ended while being dragged — the screen
## manages selection state, drag-and-drop, and layout animation.

signal card_toggled(hand_index: int, selected: bool)
signal drag_started(hand_index: int)
signal card_dragged(hand_index: int, global_pos: Vector2)
signal drag_ended(hand_index: int, global_pos: Vector2)

const BG_COLOR := Color(0.98, 0.98, 0.941) # #FAFAF0
const BORDER_COLOR := Color(0.8, 0.8, 0.8) # #CCCCCC
const SELECTED_BORDER_COLOR := Color(1.0, 0.843, 0.0) # #FFD700
const SUIT_COLOR_RED := Color(0.8, 0.0, 0.0) # #CC0000
const SUIT_COLOR_DARK := Color(0.133, 0.133, 0.133) # #222222
const JOKER_BG_COLOR := Color(0.55, 0.16, 0.75) # vivid purple
const JOKER_BORDER_COLOR := Color(1.0, 0.75, 0.0) # gold
const JOKER_TEXT_COLOR := Color(1.0, 1.0, 1.0)
const CORNER_RADIUS := 8
const BORDER_WIDTH := 1
const SELECTED_BORDER_WIDTH := 4

## Pointer movement (in pixels) before a press is treated as a drag instead
## of a tap.
const DRAG_THRESHOLD_PX := 12.0

## Color the card briefly pulses to when flash_highlight() is called (used
## for the "newly drawn card" indicator).
const HIGHLIGHT_COLOR := Color(1.4, 1.3, 0.6)
const HIGHLIGHT_PULSE_COUNT := 3
const HIGHLIGHT_PULSE_DURATION := 0.25

var hand_index: int = -1
var is_selected: bool = false
var card: Card

var top_left_label: Label
var center_label: Label
var bottom_right_label: Label

var _pressing: bool = false
var _dragging: bool = false
var _press_start_global: Vector2 = Vector2.ZERO

func _ready() -> void:
	_update_style()

func setup(p_card: Card, p_hand_index: int) -> void:
	card = p_card
	hand_index = p_hand_index

	# setup() may run before _ready() (e.g. discard pile cards are configured
	# before being added to the scene tree), so resolve labels on demand.
	if top_left_label == null:
		top_left_label = $TopLeftLabel
		center_label = $CenterLabel
		bottom_right_label = $BottomRightLabel

	var color: Color = SUIT_COLOR_DARK
	var corner_text: String
	var center_text: String

	if card.is_joker:
		color = JOKER_TEXT_COLOR
		corner_text = "JOKER"
		center_text = "JOKER"
		top_left_label.add_theme_font_size_override("font_size", 13)
		bottom_right_label.add_theme_font_size_override("font_size", 13)
		center_label.add_theme_font_size_override("font_size", 22)
	else:
		var is_red := card.suit == Card.Suit.HEARTS or card.suit == Card.Suit.DIAMONDS
		color = SUIT_COLOR_RED if is_red else SUIT_COLOR_DARK
		corner_text = card.to_display_string()
		center_text = card.get_suit_symbol()

	top_left_label.text = corner_text
	bottom_right_label.text = corner_text
	center_label.text = center_text

	for label in [top_left_label, bottom_right_label, center_label]:
		label.add_theme_color_override("font_color", color)

	_update_style()

func set_selected(selected: bool) -> void:
	is_selected = selected
	_update_style()

## Plays a brief golden pulse, used to draw attention to a newly drawn card.
func flash_highlight() -> void:
	modulate = Color.WHITE
	var tween := create_tween()
	tween.set_loops(HIGHLIGHT_PULSE_COUNT)
	tween.tween_property(self, "modulate", HIGHLIGHT_COLOR, HIGHLIGHT_PULSE_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, HIGHLIGHT_PULSE_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Custom press/drag/tap handling: a press that moves more than
## DRAG_THRESHOLD_PX before release is a drag (drag_started/card_dragged/
## drag_ended); otherwise it's a tap that toggles selection (card_toggled).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_dragging = false
			_press_start_global = event.global_position
		elif _pressing:
			if _dragging:
				drag_ended.emit(hand_index, event.global_position)
			else:
				is_selected = !is_selected
				_update_style()
				card_toggled.emit(hand_index, is_selected)
			_pressing = false
			_dragging = false
	elif event is InputEventMouseMotion and _pressing:
		if not _dragging and event.global_position.distance_to(_press_start_global) > DRAG_THRESHOLD_PX:
			_dragging = true
			drag_started.emit(hand_index)
		if _dragging:
			card_dragged.emit(hand_index, event.global_position)

func _update_style() -> void:
	var is_joker_card := card != null and card.is_joker
	var style := StyleBoxFlat.new()
	style.bg_color = JOKER_BG_COLOR if is_joker_card else BG_COLOR
	style.set_corner_radius_all(CORNER_RADIUS)
	if is_selected:
		style.set_border_width_all(SELECTED_BORDER_WIDTH)
		style.border_color = SELECTED_BORDER_COLOR
	else:
		style.set_border_width_all(BORDER_WIDTH)
		style.border_color = JOKER_BORDER_COLOR if is_joker_card else BORDER_COLOR
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		style.shadow_size = 3
		style.shadow_offset = Vector2(1, 2)
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("disabled", style)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
