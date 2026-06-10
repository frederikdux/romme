extends Control

## Top-level screen for a single match. Owns a GameState, renders it into the
## scene's UI nodes, and forwards button/card presses back into GameState.
## This script may freely depend on Control/Button/etc — GameState must not.

const CardViewScene: PackedScene = preload("res://scenes/components/card_view.tscn")

## Hand card size (min 65x90) and how much stays visible per overlapping card
## (achieved via negative HBoxContainer separation, set in the .tscn).
const CARD_WIDTH := 65.0
const CARD_HEIGHT := 90.0
## Pixels a selected card moves upward. Slot height = CARD_HEIGHT + SELECTION_LIFT_PX.
const SELECTION_LIFT_PX := 20.0

## Size of a single mini card inside a table meld group, and how much
## consecutive cards overlap (achieved via negative HBoxContainer separation).
const MELD_CARD_WIDTH := 60.0
const MELD_CARD_HEIGHT := 90.0
const MELD_CARD_OVERLAP := 15.0
const MELD_GROUP_PADDING := 8.0

## Size of a face-down card in the opponent's hand row (real card-back size,
## ~60% overlap achieved via negative HBoxContainer separation in the .tscn).
const OPPONENT_CARD_WIDTH := 50.0
const OPPONENT_CARD_HEIGHT := 70.0

## Size of the deck/discard pile cards on the table, and the offset of the
## "stacked" shadow cards behind the front card.
const PILE_CARD_WIDTH := 90.0
const PILE_CARD_HEIGHT := 125.0
const PILE_STACK_OFFSET := 6.0
const PILE_STACK_DEPTH := 2

## Above this many penalty points in hand, the player's score is shown in
## orange instead of green in the header bar.
const HIGH_PENALTY_THRESHOLD := 50
const SCORE_COLOR_LOW := Color(0.298, 0.686, 0.314) # #4CAF50
const SCORE_COLOR_HIGH := Color(1.0, 0.596, 0.0) # #FF9800
const HEADER_TEXT_COLOR := Color(1.0, 1.0, 1.0)

## The three phases of the human's turn, shown by the phase indicator.
enum TurnPhase { DRAW, MELD, DISCARD }
const TURN_PHASE_NAMES := ["Ziehen", "Legen", "Abwerfen"]

const PHASE_COLOR_ACTIVE := Color(1.0, 1.0, 1.0)
const PHASE_COLOR_DONE := Color(0.3, 0.85, 0.3)
const PHASE_COLOR_PENDING := Color(0.5, 0.5, 0.5, 0.6)
const PHASE_ARROW_COLOR := Color(0.5, 0.5, 0.5)
const PHASE_FONT_SIZE := 16

## Opacity applied to action buttons that are disabled, so the player can see
## at a glance which actions aren't relevant in the current turn phase.
const DISABLED_BUTTON_OPACITY := 0.35

## Action button accent colors.
const COLOR_ACCENT_BLUE := Color(0.129, 0.588, 0.953) # #2196F3
const COLOR_GREEN := Color(0.298, 0.686, 0.314) # #4CAF50
const COLOR_RED := Color(0.957, 0.263, 0.212) # #F44336
const COLOR_GREY_NEUTRAL := Color(0.45, 0.45, 0.45)
const COLOR_GREY_DARK := Color(0.28, 0.28, 0.28)

## Background / table colors.
const COLOR_BACKGROUND := Color(0.102, 0.18, 0.102) # #1a2e1a
const COLOR_TISCH_BG := Color(0.176, 0.29, 0.176) # #2d4a2d
const COLOR_PANEL_BG := Color(0.227, 0.227, 0.227)

## Cream card-face color and border, used for the discard pile's
## faint "cards behind" and empty-pile placeholder.
const CARD_FACE_COLOR := Color(0.98, 0.98, 0.941) # #FAFAF0
const CARD_BORDER_COLOR := Color(0.8, 0.8, 0.8) # #CCCCCC

var game_state: GameState

## Indices of selected cards in the human's hand.
var selected_card_indices: Array[int] = []
## Index into game_state.table_melds of the meld targeted for Anlegen; -1 = none.
var selected_meld_index: int = -1
## CardView references for each hand slot — rebuilt by _render_hand.
## Used to animate offset_top/offset_bottom without touching layout minimum sizes.
var _card_views: Array[CardView] = []

var background_rect: ColorRect
var header_player_label: Label
var header_round_label: Label
var header_opponent_label: Label
var player_hand_area: Control
var table_area: Control
var tisch_area: PanelContainer
var melds_row: Control
var melds_scroll: Control
var empty_melds_label: Control
var opponent_area: PanelContainer
var opponent_hand_area: Control
var opponent_badge: PanelContainer
var opponent_badge_label: Label
## References to the dynamically rebuilt pile views — used as animation
## start/end points for the bot draw/discard "flying card" effect.
var deck_pile_view: Control
var discard_pile_view: Control
var draw_deck_button: Button
var draw_discard_button: Button
var sort_button: Button
var end_turn_button: Button
var new_game_button: Button
var debug_label: Label
var meldung_legen_button: Button
var anlegen_button: Button
var abwerfen_button: Button
var deselect_button: Button
var phase_indicator_row: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	background_rect = _require_node("Background") as ColorRect
	header_player_label = _require_node("PlayerScoreLabel") as Label
	header_round_label = _require_node("RoundLabel") as Label
	header_opponent_label = _require_node("OpponentScoreLabel") as Label
	player_hand_area = _require_node("PlayerHandArea") as Control
	table_area = _require_node("TableArea") as Control
	tisch_area = _require_node("TischArea") as PanelContainer
	melds_row = _require_node("MeldsRow") as Control
	melds_scroll = _require_node("MeldsScroll") as Control
	empty_melds_label = _require_node("EmptyMeldsLabel") as Control
	opponent_area = _require_node("OpponentArea") as PanelContainer
	opponent_hand_area = _require_node("OpponentHandArea") as Control
	opponent_badge = _require_node("OpponentBadge") as PanelContainer
	opponent_badge_label = _require_node("OpponentBadgeLabel") as Label
	draw_deck_button = _require_node("DrawDeckButton") as Button
	draw_discard_button = _require_node("DrawDiscardButton") as Button
	sort_button = _require_node("SortButton") as Button
	end_turn_button = _require_node("EndTurnButton") as Button
	new_game_button = _require_node("NewGameButton") as Button
	debug_label = _require_node("DebugLabel") as Label
	meldung_legen_button = _require_node("MeldungLegenButton") as Button
	anlegen_button = _require_node("AnlegenButton") as Button
	abwerfen_button = _require_node("AbwerfenButton") as Button
	deselect_button = _require_node("DeselectButton") as Button
	phase_indicator_row = _require_node("PhaseIndicatorRow") as Control

	draw_deck_button.pressed.connect(_on_draw_deck_pressed)
	draw_discard_button.pressed.connect(_on_draw_discard_pressed)
	sort_button.pressed.connect(_on_sort_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	meldung_legen_button.pressed.connect(_on_meldung_legen_pressed)
	anlegen_button.pressed.connect(_on_anlegen_pressed)
	abwerfen_button.pressed.connect(_on_abwerfen_pressed)
	deselect_button.pressed.connect(_on_deselect_pressed)

	background_rect.color = COLOR_BACKGROUND

	var tisch_style: StyleBoxFlat = StyleBoxFlat.new()
	tisch_style.bg_color = COLOR_TISCH_BG
	tisch_style.set_corner_radius_all(8)
	tisch_style.set_content_margin_all(10)
	tisch_area.add_theme_stylebox_override("panel", tisch_style)

	var opponent_style: StyleBoxFlat = StyleBoxFlat.new()
	opponent_style.bg_color = COLOR_PANEL_BG
	opponent_style.set_corner_radius_all(8)
	opponent_style.set_content_margin_all(10)
	opponent_area.add_theme_stylebox_override("panel", opponent_style)

	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.8, 0.2, 0.2)
	badge_style.set_corner_radius_all(25)
	opponent_badge.add_theme_stylebox_override("panel", badge_style)

	# Static button colors — never change with turn phase.
	_style_button(sort_button, COLOR_GREY_NEUTRAL)
	_style_button(end_turn_button, COLOR_GREY_DARK)
	_style_button(new_game_button, COLOR_GREY_DARK)

	game_state = GameState.new()
	game_state.new_game()
	_refresh_ui()

## Finds a required child node by name or fails loudly.
func _require_node(node_name: String) -> Node:
	var node := find_child(node_name, true, false)
	if node == null:
		var message := "GameScreen is missing the required node '%s'. Add it to game_screen.tscn." % node_name
		push_error(message)
		assert(false, message)
	return node

# ── Button handlers ───────────────────────────────────────────────────────────

func _on_draw_deck_pressed() -> void:
	_clear_selection()
	game_state.human_draw_from_deck()
	_refresh_ui()

func _on_draw_discard_pressed() -> void:
	_clear_selection()
	game_state.human_draw_from_discard()
	_refresh_ui()

func _on_sort_pressed() -> void:
	_clear_selection()
	game_state.human_sort_hand()
	_refresh_ui()

func _on_end_turn_pressed() -> void:
	var should_animate := not game_state.is_human_turn() and not game_state.game_over

	# Capture pile/opponent positions BEFORE the state changes and the UI
	# rebuilds, so the animation can fly between the old (still valid) rects.
	var deck_rect := deck_pile_view.get_global_rect()
	var discard_rect := discard_pile_view.get_global_rect()
	var opponent_rect := opponent_hand_area.get_global_rect()
	var opponent_pos := opponent_rect.position + Vector2(opponent_rect.size.x, opponent_rect.size.y * 0.5)

	game_state.bot_take_turn_simple()
	_refresh_ui()

	if should_animate:
		_animate_bot_turn(deck_rect, opponent_pos, discard_rect)

func _on_new_game_pressed() -> void:
	_clear_selection()
	game_state.new_game()
	_refresh_ui()

func _on_meldung_legen_pressed() -> void:
	if game_state.human_lay_meld(selected_card_indices):
		_clear_selection()
	_refresh_ui()

func _on_anlegen_pressed() -> void:
	if selected_meld_index < 0 or selected_card_indices.is_empty():
		return
	if game_state.human_extend_meld(selected_meld_index, selected_card_indices):
		_clear_selection()
	_refresh_ui()

func _on_abwerfen_pressed() -> void:
	if selected_card_indices.size() != 1:
		return
	if game_state.human_discard_card(selected_card_indices[0]):
		_clear_selection()
	_refresh_ui()

func _on_deselect_pressed() -> void:
	_clear_selection()
	_refresh_ui()

## Toggles selection of a table meld (click to select, click again to deselect).
func _on_meld_tapped(meld_index: int) -> void:
	selected_meld_index = -1 if selected_meld_index == meld_index else meld_index
	_update_action_buttons()
	_render_phase_indicator()
	_render_tisch()

# ── Card selection ────────────────────────────────────────────────────────────

## Called by CardView on press. Updates selection state and animates the card
## within its fixed-size slot using offset_top/offset_bottom (no layout changes).
func _on_card_toggled(hand_index: int, selected: bool) -> void:
	if selected:
		if not selected_card_indices.has(hand_index):
			selected_card_indices.append(hand_index)
	else:
		selected_card_indices.erase(hand_index)
	_animate_card_lift(hand_index, selected)
	_update_action_buttons()
	_render_phase_indicator()

## Animates a card up/down by tweening offset_top and offset_bottom on the
## CardView. Crucially: this never changes any node's custom_minimum_size, so
## Godot's layout engine is never triggered and the screen never shifts.
func _animate_card_lift(hand_index: int, selected: bool) -> void:
	if hand_index < 0 or hand_index >= _card_views.size():
		return
	var card_view := _card_views[hand_index]
	if not is_instance_valid(card_view):
		return
	var top_target: float = 0.0 if selected else SELECTION_LIFT_PX
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_view, "offset_top", top_target, 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_view, "offset_bottom", top_target + CARD_HEIGHT, 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _clear_selection() -> void:
	selected_card_indices.clear()
	selected_meld_index = -1

# ── UI refresh ────────────────────────────────────────────────────────────────

## Sets a button's enabled state. Disabled buttons stay visible (so the
## fixed-height action rows never resize) but are dimmed and use a
## "not allowed" cursor to make clear they're not relevant right now.
func _set_button_state(button: Button, enabled: bool) -> void:
	button.visible = true
	button.disabled = not enabled
	button.modulate.a = 1.0 if enabled else DISABLED_BUTTON_OPACITY
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW if enabled else Control.CURSOR_FORBIDDEN

## Applies a flat, rounded background color (with hover/pressed/disabled
## variants) to an action button.
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

func _update_action_buttons() -> void:
	var count: int = selected_card_indices.size()
	var has_target: bool = selected_meld_index >= 0
	var drawn: bool = game_state.human_has_drawn
	var is_human: bool = game_state.is_human_turn()
	var over: bool = game_state.game_over

	# Ziehen-Phase: drawing is only possible before a card has been drawn.
	var can_draw: bool = is_human and not drawn and not over
	_set_button_state(draw_deck_button, can_draw)
	_set_button_state(draw_discard_button, can_draw)
	_style_button(draw_deck_button, COLOR_ACCENT_BLUE if can_draw else COLOR_GREY_NEUTRAL)
	_style_button(draw_discard_button, COLOR_ACCENT_BLUE if can_draw else COLOR_GREY_NEUTRAL)
	end_turn_button.disabled = is_human or over
	sort_button.disabled = over

	# Context buttons — always in ContextActionsRow (fixed height, always
	# visible); disabled + dimmed when not relevant to the current phase.
	_set_button_state(meldung_legen_button, count >= 3 and drawn and is_human and not over)
	_set_button_state(anlegen_button, count >= 1 and has_target and drawn
							  and is_human and game_state.human_has_melded and not over)
	_set_button_state(abwerfen_button, count == 1 and drawn and is_human and not over)
	_set_button_state(deselect_button, (count > 0 or has_target) and not over)

	_style_button(meldung_legen_button, COLOR_GREEN)
	_style_button(anlegen_button, COLOR_ACCENT_BLUE)
	_style_button(abwerfen_button, COLOR_RED)
	_style_button(deselect_button, COLOR_GREY_NEUTRAL)

func _refresh_ui() -> void:
	_render_header()
	_render_phase_indicator()
	_render_hand()
	_render_table()
	_render_tisch()
	_render_opponent_hand()
	_update_action_buttons()
	debug_label.text = game_state.get_status_text()

# ── Turn phase indicator ──────────────────────────────────────────────────────

## Derives the human's current turn phase from game state and selection:
## - DRAW: before a card has been drawn this turn
## - DISCARD: drawn, and exactly one card is selected for discarding
## - MELD: drawn, anything else (laying/extending melds, no/other selection)
func _current_turn_phase() -> int:
	if not game_state.human_has_drawn:
		return TurnPhase.DRAW
	if selected_card_indices.size() == 1 and selected_meld_index < 0:
		return TurnPhase.DISCARD
	return TurnPhase.MELD

## Rebuilds the "● Ziehen → ○ Legen → ○ Abwerfen" indicator: completed phases
## get a checkmark, the active phase a filled/bold circle, and upcoming
## phases an empty, grayed-out circle. While it's the bot's turn (or the game
## is over), no phase is "active" — all three are shown grayed out.
func _render_phase_indicator() -> void:
	for child in phase_indicator_row.get_children():
		child.queue_free()

	var current_phase: int = -1
	if game_state.is_human_turn() and not game_state.game_over:
		current_phase = _current_turn_phase()

	var bold_font := FontVariation.new()
	bold_font.base_font = ThemeDB.fallback_font
	bold_font.variation_embolden = 1.2

	for phase in range(TURN_PHASE_NAMES.size()):
		if phase > 0:
			var arrow := Label.new()
			arrow.text = "→"
			arrow.add_theme_font_size_override("font_size", PHASE_FONT_SIZE)
			arrow.add_theme_color_override("font_color", PHASE_ARROW_COLOR)
			phase_indicator_row.add_child(arrow)

		var step := Label.new()
		step.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		step.add_theme_font_size_override("font_size", PHASE_FONT_SIZE)

		if phase < current_phase:
			step.text = "✓ %s" % TURN_PHASE_NAMES[phase]
			step.add_theme_color_override("font_color", PHASE_COLOR_DONE)
		elif phase == current_phase:
			step.text = "● %s" % TURN_PHASE_NAMES[phase]
			step.add_theme_color_override("font_color", PHASE_COLOR_ACTIVE)
			step.add_theme_font_override("font", bold_font)
		else:
			step.text = "○ %s" % TURN_PHASE_NAMES[phase]
			step.add_theme_color_override("font_color", PHASE_COLOR_PENDING)

		phase_indicator_row.add_child(step)

# ── Header rendering ──────────────────────────────────────────────────────────

## Updates the top header bar: own/opponent penalty points (if the round
## ended right now) and the round counter. Own points turn orange once they
## exceed HIGH_PENALTY_THRESHOLD, green otherwise; round/opponent stay white.
func _render_header() -> void:
	var player_points: int = game_state.get_human_penalty_points()
	var opponent_points: int = game_state.get_bot_penalty_points()

	header_player_label.text = "Spieler: %d Punkte" % player_points
	header_opponent_label.text = "Gegner: %d Punkte" % opponent_points
	header_round_label.text = "Runde %d" % game_state.round_number

	header_opponent_label.add_theme_color_override("font_color", HEADER_TEXT_COLOR)
	header_round_label.add_theme_color_override("font_color", HEADER_TEXT_COLOR)

	var player_color: Color = SCORE_COLOR_HIGH if player_points > HIGH_PENALTY_THRESHOLD else SCORE_COLOR_LOW
	header_player_label.add_theme_color_override("font_color", player_color)

# ── Hand rendering ────────────────────────────────────────────────────────────

func _render_hand() -> void:
	_card_views.clear()
	for child in player_hand_area.get_children():
		child.queue_free()

	var hand := game_state.get_human_hand()
	var slot_height: float = CARD_HEIGHT + SELECTION_LIFT_PX

	for hand_index in range(hand.size()):
		# Each card slot is a plain Control — NOT a Container.
		# The CardView is positioned inside using anchors + offsets.
		# Changing offset_top/offset_bottom during animation never touches
		# custom_minimum_size, so the layout engine is never re-triggered.
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(CARD_WIDTH, slot_height)
		player_hand_area.add_child(slot)

		var is_sel := selected_card_indices.has(hand_index)
		var top_offset: float = 0.0 if is_sel else SELECTION_LIFT_PX

		var card_view := CardViewScene.instantiate() as CardView
		# Anchor left-right to fill slot width; top fixed (no bottom anchor).
		card_view.anchor_left = 0.0
		card_view.anchor_right = 1.0
		card_view.anchor_top = 0.0
		card_view.anchor_bottom = 0.0
		card_view.offset_left = 0.0
		card_view.offset_right = 0.0
		card_view.offset_top = top_offset
		card_view.offset_bottom = top_offset + CARD_HEIGHT
		slot.add_child(card_view)

		card_view.setup(hand[hand_index], hand_index)
		card_view.card_toggled.connect(_on_card_toggled)
		if is_sel:
			card_view.set_selected(true)
		_card_views.append(card_view)

# ── Table rendering ───────────────────────────────────────────────────────────

func _render_table() -> void:
	for child in table_area.get_children():
		child.queue_free()

	deck_pile_view = _build_deck_pile_view()
	table_area.add_child(deck_pile_view)

	discard_pile_view = _build_discard_pile_view()
	table_area.add_child(discard_pile_view)

## Builds the deck pile: a title above a stack of face-down CardBack visuals —
## two faint, offset "shadow" cards behind a front card that also shows the
## remaining card count.
func _build_deck_pile_view() -> Control:
	var outer := VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	outer.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Deck"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	outer.add_child(title)

	var stack := Control.new()
	stack.custom_minimum_size = Vector2(
		PILE_CARD_WIDTH + PILE_STACK_OFFSET * PILE_STACK_DEPTH,
		PILE_CARD_HEIGHT + PILE_STACK_OFFSET * PILE_STACK_DEPTH)
	stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.add_child(stack)

	for i in range(PILE_STACK_DEPTH, 0, -1):
		var shadow := CardBack.new()
		shadow.size = Vector2(PILE_CARD_WIDTH, PILE_CARD_HEIGHT)
		shadow.position = Vector2(i, i) * PILE_STACK_OFFSET
		shadow.modulate = Color(1.0, 1.0, 1.0, 0.5)
		stack.add_child(shadow)

	var front := CardBack.new()
	front.size = Vector2(PILE_CARD_WIDTH, PILE_CARD_HEIGHT)
	stack.add_child(front)

	var count_label := Label.new()
	count_label.text = "%d" % game_state.draw_deck.size()
	count_label.add_theme_font_size_override("font_size", 36)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.add_child(count_label)

	return outer

## Builds the discard pile: a title above a stack with the top card shown
## fully (correct color/suit via CardView) and faint cream cards behind it.
func _build_discard_pile_view() -> Control:
	var outer := VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	outer.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Ablage"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	outer.add_child(title)

	var stack := Control.new()
	stack.custom_minimum_size = Vector2(
		PILE_CARD_WIDTH + PILE_STACK_OFFSET * PILE_STACK_DEPTH,
		PILE_CARD_HEIGHT + PILE_STACK_OFFSET * PILE_STACK_DEPTH)
	stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.add_child(stack)

	var top_card: Card = game_state.get_top_discard_card()

	if top_card != null:
		for i in range(PILE_STACK_DEPTH, 0, -1):
			var shadow := PanelContainer.new()
			shadow.size = Vector2(PILE_CARD_WIDTH, PILE_CARD_HEIGHT)
			shadow.position = Vector2(i, i) * PILE_STACK_OFFSET
			shadow.modulate = Color(1.0, 1.0, 1.0, 0.5)
			shadow.add_theme_stylebox_override("panel", _build_card_face_style())
			stack.add_child(shadow)

		var card_view := CardViewScene.instantiate() as CardView
		card_view.size = Vector2(PILE_CARD_WIDTH, PILE_CARD_HEIGHT)
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_view.disabled = true
		stack.add_child(card_view)
		card_view.setup(top_card, -1)
	else:
		var empty := PanelContainer.new()
		empty.size = Vector2(PILE_CARD_WIDTH, PILE_CARD_HEIGHT)
		empty.add_theme_stylebox_override("panel", _build_card_face_style())
		stack.add_child(empty)

	return outer

## Plain cream card-face style (#FAFAF0 bg, #CCCCCC border, 8px radius), used
## for the discard pile's faint "cards behind" and the empty-pile placeholder.
func _build_card_face_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_FACE_COLOR
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = CARD_BORDER_COLOR
	return style

# ── Opponent hand rendering ──────────────────────────────────────────────────

## Renders the opponent's hand as face-down, overlapping cards and updates
## the card-count badge.
func _render_opponent_hand() -> void:
	for child in opponent_hand_area.get_children():
		child.queue_free()

	var count: int = game_state.bot_player.hand.size()
	opponent_badge_label.text = "%d" % count

	for _i in range(count):
		opponent_hand_area.add_child(_build_card_back())

## Builds a small face-down card visual (used for the opponent's hand and for
## the bot draw/discard flying-card animation).
func _build_card_back(card_size: Vector2 = Vector2(OPPONENT_CARD_WIDTH, OPPONENT_CARD_HEIGHT)) -> Control:
	var back := CardBack.new()
	back.custom_minimum_size = card_size
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return back

# ── Bot turn animation ────────────────────────────────────────────────────────

## Spawns a small card visual that flies from from_global to to_global and
## fades out, then frees itself. Purely decorative — game state is already
## updated by the time this plays.
func _spawn_flying_card(from_global: Vector2, to_global: Vector2) -> void:
	var card := _build_card_back()
	card.custom_minimum_size = Vector2(OPPONENT_CARD_WIDTH, OPPONENT_CARD_HEIGHT)
	card.size = Vector2(OPPONENT_CARD_WIDTH, OPPONENT_CARD_HEIGHT)
	card.z_index = 100
	add_child(card)
	card.global_position = from_global

	var tween := create_tween()
	tween.tween_property(card, "global_position", to_global, 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(card, "modulate:a", 0.0, 0.15).set_delay(0.1)
	tween.tween_callback(card.queue_free)

## Plays the "bot draws a card" and "bot discards a card" flying animations.
## Captures positions of the deck pile, opponent hand, and discard pile
## BEFORE the state-changing call so the old (still valid) layout rects can
## be used as animation endpoints.
func _animate_bot_turn(deck_rect: Rect2, opponent_anchor: Vector2, discard_rect: Rect2) -> void:
	var deck_pos := deck_rect.position + deck_rect.size * 0.5 - Vector2(OPPONENT_CARD_WIDTH, OPPONENT_CARD_HEIGHT) * 0.5
	var opponent_pos := opponent_anchor - Vector2(OPPONENT_CARD_WIDTH, OPPONENT_CARD_HEIGHT) * 0.5
	var discard_pos := discard_rect.position + discard_rect.size * 0.5 - Vector2(OPPONENT_CARD_WIDTH, OPPONENT_CARD_HEIGHT) * 0.5

	_spawn_flying_card(deck_pos, opponent_pos)

	var discard_tween := get_tree().create_timer(0.2)
	discard_tween.timeout.connect(func() -> void:
		_spawn_flying_card(opponent_pos, discard_pos)
	)

# ── Tisch (table melds) rendering ────────────────────────────────────────────

## Renders all table melds as horizontal, slightly-overlapping card groups in
## the scrollable MeldsRow. Shows EmptyMeldsLabel instead when there are none.
func _render_tisch() -> void:
	for child in melds_row.get_children():
		child.queue_free()

	var melds: Array = game_state.table_melds
	var is_empty := melds.is_empty()
	empty_melds_label.visible = is_empty
	melds_scroll.visible = not is_empty

	for meld_index in range(melds.size()):
		var entry: Dictionary = melds[meld_index]
		melds_row.add_child(_build_meld_group(meld_index, entry))

## Builds a clickable group representing one table meld as overlapping mini
## cards. Own melds use a neutral background; opponent melds a reddish tint.
## Highlighted with a green border when selected (for Anlegen).
func _build_meld_group(meld_index: int, meld_entry: Dictionary) -> Control:
	var owner: int = meld_entry.get("owner", GameState.HUMAN_INDEX)
	var cards: Array = meld_entry.get("cards", [])
	var is_own := owner == GameState.HUMAN_INDEX

	var card_count := cards.size()
	var content_width: float = (card_count * MELD_CARD_WIDTH
		- max(0, card_count - 1) * MELD_CARD_OVERLAP + 2.0 * MELD_GROUP_PADDING)

	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(content_width, MELD_CARD_HEIGHT + 2.0 * MELD_GROUP_PADDING)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.3) if is_own else Color(0.32, 0.22, 0.22)
	style.set_corner_radius_all(6)
	if meld_index == selected_meld_index:
		style.border_color = Color(0.2, 0.9, 0.2)
		style.set_border_width_all(3)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", -int(MELD_CARD_OVERLAP))
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = MELD_GROUP_PADDING
	hbox.offset_top = MELD_GROUP_PADDING
	hbox.offset_right = -MELD_GROUP_PADDING
	hbox.offset_bottom = -MELD_GROUP_PADDING
	btn.add_child(hbox)

	for card in cards:
		hbox.add_child(_build_mini_card(card))

	btn.pressed.connect(_on_meld_tapped.bind(meld_index))
	return btn

## Builds a small, non-interactive card visual used inside a meld group, with
## the same cream face and red/dark suit colors as the hand cards.
func _build_mini_card(card: Card) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(MELD_CARD_WIDTH, MELD_CARD_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _build_card_face_style())

	var label := Label.new()
	label.text = card.to_display_string()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	var is_red := card.suit == Card.Suit.HEARTS or card.suit == Card.Suit.DIAMONDS
	label.add_theme_color_override("font_color", Color(0.8, 0.0, 0.0) if is_red else Color(0.133, 0.133, 0.133))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	return panel
