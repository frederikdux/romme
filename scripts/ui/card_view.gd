class_name CardView
extends Button

## Visual representation of a single playing card: cream background, rank +
## suit symbol in the top-left and (rotated 180°) bottom-right corners, and a
## big suit symbol in the center. Emits card_toggled when tapped — the screen
## manages selection state and layout animation (spacer approach).

signal card_toggled(hand_index: int, selected: bool)

const BG_COLOR := Color(0.98, 0.98, 0.941) # #FAFAF0
const BORDER_COLOR := Color(0.8, 0.8, 0.8) # #CCCCCC
const SELECTED_BORDER_COLOR := Color(1.0, 0.843, 0.0) # #FFD700
const SUIT_COLOR_RED := Color(0.8, 0.0, 0.0) # #CC0000
const SUIT_COLOR_DARK := Color(0.133, 0.133, 0.133) # #222222
const CORNER_RADIUS := 8
const BORDER_WIDTH := 1
const SELECTED_BORDER_WIDTH := 4

var hand_index: int = -1
var is_selected: bool = false
var card: Card

var top_left_label: Label
var center_label: Label
var bottom_right_label: Label

func _ready() -> void:
	pressed.connect(_on_pressed)
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
		corner_text = "JK"
		center_text = "★"
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

func set_selected(selected: bool) -> void:
	is_selected = selected
	_update_style()

func _on_pressed() -> void:
	is_selected = !is_selected
	_update_style()
	card_toggled.emit(hand_index, is_selected)

func _update_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.set_corner_radius_all(CORNER_RADIUS)
	if is_selected:
		style.set_border_width_all(SELECTED_BORDER_WIDTH)
		style.border_color = SELECTED_BORDER_COLOR
	else:
		style.set_border_width_all(BORDER_WIDTH)
		style.border_color = BORDER_COLOR
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		style.shadow_size = 3
		style.shadow_offset = Vector2(1, 2)
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("disabled", style)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
