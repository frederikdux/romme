extends Control

## Top-level screen for a single match. Owns a GameState, renders it into the
## scene's UI nodes, and forwards button/card presses back into GameState.
## This script may freely depend on Control/Button/etc — GameState must not.

const CardViewScene: PackedScene = preload("res://scenes/components/card_view.tscn")

## Hand card size. Cards always span the full width of PlayerHandArea —
## _render_hand() computes the HBoxContainer separation from the available
## width and the current card count so they spread out evenly.
const CARD_WIDTH := 130.0
const CARD_HEIGHT := 180.0
## Pixels a selected card moves upward. Slot height = CARD_HEIGHT + SELECTION_LIFT_PX.
const SELECTION_LIFT_PX := 36.0

## MarginContainer's left+right margins, used as a fallback to compute
## PlayerHandArea's width before the first layout pass (when its .size.x is
## still 0).
const HORIZONTAL_MARGIN := 32.0

## Size of a single mini card inside a table meld group, and how much
## consecutive cards overlap (achieved via negative HBoxContainer separation).
const MELD_CARD_WIDTH := 100.0
const MELD_CARD_HEIGHT := 150.0
const MELD_CARD_OVERLAP := 25.0
const MELD_GROUP_PADDING := 10.0

## Size of a face-down card in an opponent's hand row, for the single-opponent
## (N=1) layout vs. the compact layout (N>=2). Separation between cards is
## computed in _fill_opponent_hand_area() to spread/overlap them to fit.
const OPPONENT_CARD_WIDTH_SINGLE := 50.0
const OPPONENT_CARD_HEIGHT_SINGLE := 70.0
const OPPONENT_CARD_WIDTH_COMPACT := 38.0
const OPPONENT_CARD_HEIGHT_COMPACT := 53.0
const OPPONENT_NAME_FONT_SIZE_SINGLE := 34
const OPPONENT_NAME_FONT_SIZE_COMPACT := 22
const OPPONENT_BADGE_FONT_SIZE_SINGLE := 30
const OPPONENT_BADGE_FONT_SIZE_COMPACT := 20
const OPPONENT_BADGE_SIZE_SINGLE := 50.0
const OPPONENT_BADGE_SIZE_COMPACT := 36.0
const OPPONENT_ROW_HEIGHT_SINGLE := 100.0
const OPPONENT_ROW_HEIGHT_COMPACT := 92.0
const OPPONENT_ROW_GAP := 8.0
## Highlight for the opponent slot whose turn it currently is.
const OPPONENT_ACTIVE_BORDER_COLOR := Color(1.0, 0.85, 0.2) # gold
const OPPONENT_ACTIVE_BORDER_WIDTH := 3
## Visual size of the bot draw/discard "flying card" animation, regardless of
## the opponent layout's (single/compact) card size.
const FLYING_CARD_SIZE := Vector2(50.0, 70.0)

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
const PHASE_FONT_SIZE := 24

## Opacity applied to action buttons that are disabled, so the player can see
## at a glance which actions aren't relevant in the current turn phase.
const DISABLED_BUTTON_OPACITY := 0.3

## Delay before each bot automatically takes its turn (after the human
## discards, and between chained bots), so the turn change feels natural.
const BOT_TURN_DELAY_SEC := 0.8
## Pause between each visible step of a bot's turn (draw / meld / extend /
## discard) so the sequence is easy to follow.
const BOT_STEP_DELAY_SEC := 0.5

## Pulsing glow shown around the deck/discard piles while they're clickable
## (i.e. during the draw phase), and the hover/touch scale-up factor.
const PILE_GLOW_COLOR := Color(1.0, 0.85, 0.2) # gold
const PILE_GLOW_SHADOW_SIZE := 18
const PILE_HOVER_SCALE := 1.08

## Drag & drop tuning. The dragged card scales up and lifts slightly so it
## visually separates from the hand; other cards in the hand re-flow toward
## their preview position with a short tween (DRAG_REORDER_TWEEN_SEC).
const DRAG_SCALE := 1.12
const DRAG_LIFT_PX := 20.0
const DRAG_REORDER_TWEEN_SEC := 0.08
## Opacity applied to the other cards of a multi-card selection while one of
## them is being dragged, to show they're moving together.
const DRAG_GROUP_DIM_ALPHA := 0.4
## Border shown around a table meld / the Tisch area while a card is dragged
## over it: green if dropping there would be a valid action, red otherwise.
const DROP_VALID_COLOR := Color(0.2, 0.9, 0.2)
const DROP_INVALID_COLOR := Color(0.9, 0.2, 0.2)
const DROP_HIGHLIGHT_BORDER_WIDTH := 4
## Duration of the flying-card animation when the human draws a card.
const NEW_CARD_FLY_DURATION := 0.3

## Pulsing glow applied to a table joker that the currently-selected hand card
## could be swapped for (Joker-Tausch), and the brief red flash shown when an
## ineligible table joker is tapped.
const JOKER_SWAP_PULSE_COLOR := Color(0.5, 1.6, 0.5)
const JOKER_SWAP_PULSE_DURATION := 0.4
const JOKER_SWAP_INVALID_FLASH_SEC := 0.2

## Drop-target highlight states applied to a table meld button or the Tisch
## area while a card/group is being dragged over it.
enum DropHighlight { NONE, VALID, INVALID }

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
## Slot Controls wrapping each hand CardView, in the same order as
## _card_views — rebuilt by _render_hand. Used to read slot geometry for
## drag-and-drop math.
var _card_slots: Array[Control] = []
## Horizontal distance (px) between two adjacent hand slots' positions
## (CARD_WIDTH + separation) — recomputed by _render_hand, used by the drag
## "make way" preview.
var _drag_hand_step: float = 0.0
## Button references for each rendered table meld, in table_melds order —
## rebuilt by _render_tisch. Used to apply drag-hover highlight styles
## without a full rebuild.
var _meld_buttons: Array[Button] = []

## Precomputed TischArea panel styles, swapped during drag-over highlighting.
var _tisch_style_normal: StyleBoxFlat
var _tisch_style_valid: StyleBoxFlat
var _tisch_style_invalid: StyleBoxFlat

## Full-rect overlay (added last, on top of everything) that hosts the
## floating drag preview and the new-card flying animation.
var _drag_layer: Control

## Drag state — see _on_card_drag_started/_on_card_dragged/_on_card_drag_ended.
var _drag_active: bool = false
var _drag_card_view: CardView
var _drag_badge: PanelContainer
var _drag_from_index: int = -1
## All hand indices moving together (the dragged card, plus any other
## selected cards if the dragged card was part of the selection).
var _drag_indices: Array[int] = []
## Current "make way" preview target slot (hand reorder only).
var _drag_target_slot: int = -1
## Index into table_melds currently highlighted as a drop target, or -1.
var _drag_hover_meld_index: int = -1
## True while hovering the Tisch area outside any specific meld (i.e. the
## "lay a new meld" drop target).
var _drag_hover_table: bool = false
## Whether the currently highlighted meld/table drop target would accept the
## dragged cards (drives the green/red border and the action on drop).
var _drag_hover_valid: bool = false
## Tween animating the FLIP "make way" preview offsets; killed and replaced
## whenever the preview target slot changes.
var _drag_reorder_tween: Tween

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
var opponent_area: VBoxContainer
## Hand-area HBoxContainers for each bot, indexed by (bot_number - 1).
## Rebuilt every _render_opponent_areas() call.
var _opponent_hand_areas: Array[Control] = []
## References to the dynamically rebuilt pile views — used as animation
## start/end points for the bot draw/discard "flying card" effect.
var deck_pile_view: Control
var discard_pile_view: Control
var debug_label: Label
var meldung_legen_button: Button
var anlegen_button: Button
var abwerfen_button: Button
var phase_indicator_row: Control
var settings_button: Button
var menu_overlay: Control
var menu_overlay_bg: Control
var new_game_confirm_button: Button
var menu_cancel_button: Button
var setup_overlay: Control
var opponents_1_button: Button
var opponents_2_button: Button
var opponents_3_button: Button
var opponents_4_button: Button
var options_button: Button
var options_overlay: Control
var options_overlay_bg: Control
var options_back_button: Button
var joker_count_value_label: Label
var joker_count_minus_button: Button
var joker_count_plus_button: Button
## Re-entrancy guard for _run_bot_turn_sequence().
var _bot_turn_in_progress: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	# Some content (e.g. very wide table melds or opponent hands) can report a
	# larger minimum size than the viewport. clip_contents keeps any such
	# overflow from rendering outside the screen — the root Control's own size
	# always stays the viewport size regardless of its children's minimums.
	clip_contents = true

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
	opponent_area = _require_node("OpponentArea") as VBoxContainer
	debug_label = _require_node("DebugLabel") as Label
	meldung_legen_button = _require_node("MeldungLegenButton") as Button
	anlegen_button = _require_node("AnlegenButton") as Button
	abwerfen_button = _require_node("AbwerfenButton") as Button
	phase_indicator_row = _require_node("PhaseIndicatorRow") as Control
	settings_button = _require_node("SettingsButton") as Button
	menu_overlay = _require_node("MenuOverlay") as Control
	menu_overlay_bg = _require_node("MenuOverlayBg") as Control
	new_game_confirm_button = _require_node("NewGameConfirmButton") as Button
	menu_cancel_button = _require_node("MenuCancelButton") as Button
	setup_overlay = _require_node("SetupOverlay") as Control
	opponents_1_button = _require_node("Opponents1Button") as Button
	opponents_2_button = _require_node("Opponents2Button") as Button
	opponents_3_button = _require_node("Opponents3Button") as Button
	opponents_4_button = _require_node("Opponents4Button") as Button
	options_button = _require_node("OptionsButton") as Button
	options_overlay = _require_node("OptionsOverlay") as Control
	options_overlay_bg = _require_node("OptionsOverlayBg") as Control
	options_back_button = _require_node("OptionsBackButton") as Button
	joker_count_value_label = _require_node("JokerCountValueLabel") as Label
	joker_count_minus_button = _require_node("JokerCountMinusButton") as Button
	joker_count_plus_button = _require_node("JokerCountPlusButton") as Button

	meldung_legen_button.pressed.connect(_on_meldung_legen_pressed)
	anlegen_button.pressed.connect(_on_anlegen_pressed)
	abwerfen_button.pressed.connect(_on_abwerfen_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	new_game_confirm_button.pressed.connect(_on_new_game_confirm_pressed)
	menu_cancel_button.pressed.connect(_on_menu_cancel_pressed)
	opponents_1_button.pressed.connect(_on_opponent_count_selected.bind(1))
	opponents_2_button.pressed.connect(_on_opponent_count_selected.bind(2))
	opponents_3_button.pressed.connect(_on_opponent_count_selected.bind(3))
	opponents_4_button.pressed.connect(_on_opponent_count_selected.bind(4))
	options_button.pressed.connect(_on_options_pressed)
	options_back_button.pressed.connect(_on_options_back_pressed)
	joker_count_minus_button.pressed.connect(_on_joker_count_step.bind(-1))
	joker_count_plus_button.pressed.connect(_on_joker_count_step.bind(1))

	background_rect.color = COLOR_BACKGROUND
	background_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	background_rect.gui_input.connect(_on_background_gui_input)

	menu_overlay_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_overlay_bg.gui_input.connect(_on_menu_overlay_bg_gui_input)

	options_overlay_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	options_overlay_bg.gui_input.connect(_on_options_overlay_bg_gui_input)

	var tisch_style: StyleBoxFlat = StyleBoxFlat.new()
	tisch_style.bg_color = COLOR_TISCH_BG
	tisch_style.set_corner_radius_all(8)
	tisch_style.set_content_margin_all(10)
	tisch_area.add_theme_stylebox_override("panel", tisch_style)

	_tisch_style_normal = tisch_style
	_tisch_style_valid = tisch_style.duplicate()
	_tisch_style_valid.border_color = DROP_VALID_COLOR
	_tisch_style_valid.set_border_width_all(DROP_HIGHLIGHT_BORDER_WIDTH)
	_tisch_style_invalid = tisch_style.duplicate()
	_tisch_style_invalid.border_color = DROP_INVALID_COLOR
	_tisch_style_invalid.set_border_width_all(DROP_HIGHLIGHT_BORDER_WIDTH)

	var menu_panel_style: StyleBoxFlat = StyleBoxFlat.new()
	menu_panel_style.bg_color = COLOR_PANEL_BG
	menu_panel_style.set_corner_radius_all(12)
	menu_panel_style.set_content_margin_all(24)
	(_require_node("MenuPanel") as PanelContainer).add_theme_stylebox_override("panel", menu_panel_style)
	(_require_node("SetupPanel") as PanelContainer).add_theme_stylebox_override("panel", menu_panel_style.duplicate())

	# Static button colors — never change with turn phase.
	_style_button(settings_button, COLOR_GREY_DARK)
	_style_button(new_game_confirm_button, COLOR_ACCENT_BLUE)
	_style_button(menu_cancel_button, COLOR_GREY_NEUTRAL)
	_style_button(opponents_1_button, COLOR_ACCENT_BLUE)
	_style_button(opponents_2_button, COLOR_ACCENT_BLUE)
	_style_button(opponents_3_button, COLOR_ACCENT_BLUE)
	_style_button(opponents_4_button, COLOR_ACCENT_BLUE)
	_style_button(options_button, COLOR_GREY_NEUTRAL)
	_style_button(options_back_button, COLOR_GREY_NEUTRAL)
	_style_button(joker_count_minus_button, COLOR_ACCENT_BLUE)
	_style_button(joker_count_plus_button, COLOR_ACCENT_BLUE)
	(_require_node("OptionsPanel") as PanelContainer).add_theme_stylebox_override("panel", menu_panel_style.duplicate())

	_drag_layer = Control.new()
	_drag_layer.name = &"DragLayer"
	_drag_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_layer)

	game_state = GameState.new()
	setup_overlay.visible = true

## Finds a required child node by name or fails loudly.
func _require_node(node_name: String) -> Node:
	var node := find_child(node_name, true, false)
	if node == null:
		var message := "GameScreen is missing the required node '%s'. Add it to game_screen.tscn." % node_name
		push_error(message)
		assert(false, message)
	return node

# ── Button handlers ───────────────────────────────────────────────────────────

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
	var discarded := game_state.human_discard_card(selected_card_indices[0])
	if discarded:
		_clear_selection()
	_refresh_ui()
	if discarded and not game_state.game_over and not game_state.is_human_turn():
		_schedule_bot_turn()

# ── Pile draw handlers ────────────────────────────────────────────────────────

func _on_deck_pile_pressed() -> void:
	_clear_selection()
	var from_rect := _pile_card_rect(deck_pile_view)
	var drew := game_state.human_draw_from_deck()
	_refresh_ui()
	if drew:
		_animate_drawn_card(from_rect)

func _on_discard_pile_pressed() -> void:
	_clear_selection()
	var from_rect := _pile_card_rect(discard_pile_view)
	var drew := game_state.human_draw_from_discard()
	_refresh_ui()
	if drew:
		_animate_drawn_card(from_rect)

## Returns a CARD_WIDTH x CARD_HEIGHT rect centered on the given pile view,
## used as the start/end point for the drawn-card flight animation.
func _pile_card_rect(pile_view: Control) -> Rect2:
	var pile_rect := pile_view.get_global_rect()
	var card_size := Vector2(CARD_WIDTH, CARD_HEIGHT)
	return Rect2(pile_rect.position + pile_rect.size * 0.5 - card_size * 0.5, card_size)

## Animates the just-drawn card (always the last hand card, since
## Player.add_card appends) flying from from_rect to its new hand slot, then
## flashes it to draw attention. Called after _refresh_ui() has rebuilt the
## hand with the new card.
func _animate_drawn_card(from_rect: Rect2) -> void:
	if _card_views.is_empty():
		return
	var new_view: CardView = _card_views.back()
	if not is_instance_valid(new_view):
		return

	var to_rect := new_view.get_global_rect()
	new_view.modulate.a = 0.0

	var flying := CardViewScene.instantiate() as CardView
	flying.setup(new_view.card, -1)
	flying.disabled = true
	flying.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_layer.add_child(flying)
	flying.global_position = from_rect.position
	flying.size = from_rect.size

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flying, "global_position", to_rect.position, NEW_CARD_FLY_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(flying, "size", to_rect.size, NEW_CARD_FLY_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(func() -> void:
		flying.queue_free()
		if is_instance_valid(new_view):
			new_view.modulate.a = 1.0
			new_view.flash_highlight())

# ── Bot turn ──────────────────────────────────────────────────────────────────

## Starts a short timer after the human discards, then runs the bot turn
## sequence — gives the turn change a natural pause instead of feeling instant.
func _schedule_bot_turn() -> void:
	get_tree().create_timer(BOT_TURN_DELAY_SEC).timeout.connect(_run_bot_turn_sequence)

## Runs every queued bot's turn back-to-back (1-4 bots) until play returns to
## the human or the game ends.
func _run_bot_turn_sequence() -> void:
	if _bot_turn_in_progress:
		return
	_bot_turn_in_progress = true

	while not game_state.game_over and not game_state.is_human_turn():
		await _run_single_bot_turn()
		if game_state.game_over or game_state.is_human_turn():
			break
		await get_tree().create_timer(BOT_TURN_DELAY_SEC).timeout

	_bot_turn_in_progress = false

## Runs one bot's full turn (draw -> melds* -> extends* -> discard), pacing
## each visible step with BOT_STEP_DELAY_SEC and animating flying cards
## to/from that bot's row.
func _run_single_bot_turn() -> void:
	var bot_number := game_state.current_player_index
	var bot_name := game_state.get_player_name(bot_number)
	var opponent_pos := _get_opponent_anchor(bot_number)
	var deck_rect := deck_pile_view.get_global_rect()
	var discard_rect := discard_pile_view.get_global_rect()

	game_state.status_text = "%s denkt..." % bot_name
	_refresh_ui()
	await get_tree().create_timer(BOT_STEP_DELAY_SEC).timeout

	# Draw
	var draw_result := game_state.bot_draw_step()
	if draw_result.get("card") != null:
		var deck_pos := deck_rect.position + deck_rect.size * 0.5 - FLYING_CARD_SIZE * 0.5
		var opp_pos := opponent_pos - FLYING_CARD_SIZE * 0.5
		_spawn_flying_card(deck_pos, opp_pos)
	game_state.status_text = "%s denkt..." % bot_name
	_refresh_ui()
	await get_tree().create_timer(BOT_STEP_DELAY_SEC).timeout

	# Lay melds (repeat until none left)
	var meld_result := game_state.bot_meld_step()
	while meld_result.get("laid"):
		game_state.status_text = "%s denkt..." % bot_name
		_refresh_ui()
		await get_tree().create_timer(BOT_STEP_DELAY_SEC).timeout
		meld_result = game_state.bot_meld_step()

	# Extend melds (repeat until none left)
	var extend_result := game_state.bot_extend_step()
	while extend_result.get("extended"):
		game_state.status_text = "%s denkt..." % bot_name
		_refresh_ui()
		await get_tree().create_timer(BOT_STEP_DELAY_SEC).timeout
		extend_result = game_state.bot_extend_step()

	if game_state.game_over:
		_refresh_ui()
		return

	# Discard
	var discard_result := game_state.bot_discard_step()
	if discard_result.get("discarded") != null:
		var opp_pos := opponent_pos - FLYING_CARD_SIZE * 0.5
		var discard_pos := discard_rect.position + discard_rect.size * 0.5 - FLYING_CARD_SIZE * 0.5
		_spawn_flying_card(opp_pos, discard_pos)
	_refresh_ui()

# ── Menu overlay ──────────────────────────────────────────────────────────────

func _on_settings_pressed() -> void:
	menu_overlay.visible = true

func _on_menu_cancel_pressed() -> void:
	menu_overlay.visible = false

func _on_menu_overlay_bg_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_menu_cancel_pressed()

func _on_new_game_confirm_pressed() -> void:
	menu_overlay.visible = false
	setup_overlay.visible = true

# ── Setup overlay ─────────────────────────────────────────────────────────────

func _on_opponent_count_selected(count: int) -> void:
	setup_overlay.visible = false
	_clear_selection()
	game_state.new_game(count)
	_refresh_ui()

# ── Options overlay ───────────────────────────────────────────────────────────

func _on_options_pressed() -> void:
	setup_overlay.visible = false
	options_overlay.visible = true
	_render_joker_count_label()

func _on_options_back_pressed() -> void:
	options_overlay.visible = false
	setup_overlay.visible = true

func _on_options_overlay_bg_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_options_back_pressed()

## Adjusts game_state.joker_count by delta, clamped to
## [0, GameState.MAX_JOKER_COUNT], and refreshes the value label.
func _on_joker_count_step(delta: int) -> void:
	game_state.joker_count = clampi(game_state.joker_count + delta, 0, GameState.MAX_JOKER_COUNT)
	_render_joker_count_label()

func _render_joker_count_label() -> void:
	joker_count_value_label.text = str(game_state.joker_count)

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
	_render_tisch()

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

## Deselects all selected cards/melds, animating any lifted cards back down.
## Called when the player taps an empty area of the screen.
func _deselect_all() -> void:
	if selected_card_indices.is_empty() and selected_meld_index < 0:
		return
	for hand_index in selected_card_indices:
		if hand_index >= 0 and hand_index < _card_views.size():
			var card_view := _card_views[hand_index]
			if is_instance_valid(card_view):
				card_view.set_selected(false)
		_animate_card_lift(hand_index, false)
	_clear_selection()
	_update_action_buttons()
	_render_phase_indicator()
	_render_tisch()

# ── Hand drag & drop ─────────────────────────────────────────────────────────

## Called when a hand card's press moves past the drag threshold. Determines
## which cards move together (the dragged card alone, or its whole selection
## group if it was selected), dims the other moving cards, and lifts the
## dragged CardView into _drag_layer so it floats above everything else.
func _on_card_drag_started(hand_index: int) -> void:
	if hand_index < 0 or hand_index >= _card_views.size():
		return
	var card_view := _card_views[hand_index]
	if not is_instance_valid(card_view):
		return

	# A second touch starting a new drag before the previous one's drag_ended
	# arrived would otherwise overwrite _drag_card_view and orphan its ghost
	# in _drag_layer forever (the "stuck card" bug). Cancel any drag already
	# in progress first.
	_cancel_active_drag()

	_drag_active = true
	_drag_from_index = hand_index
	_drag_target_slot = hand_index
	_drag_hover_meld_index = -1
	_drag_hover_table = false
	_drag_hover_valid = false

	if selected_card_indices.has(hand_index):
		_drag_indices = selected_card_indices.duplicate()
	else:
		_drag_indices = [hand_index]

	for i in _drag_indices:
		if i != hand_index and i >= 0 and i < _card_views.size() and is_instance_valid(_card_views[i]):
			_card_views[i].modulate.a = DRAG_GROUP_DIM_ALPHA

	# The dragged CardView stays in its slot (just hidden) so it keeps the
	# mouse-press grab that's driving this drag — reparenting the pressed
	# Control mid-gesture breaks Godot's gui_input capture and "loses" the
	# drag. A separate, input-ignoring ghost CardView in _drag_layer provides
	# the floating preview instead.
	var rect := card_view.get_global_rect()
	card_view.modulate.a = 0.0

	var ghost := CardViewScene.instantiate() as CardView
	ghost.setup(card_view.card, -1)
	ghost.disabled = true
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if card_view.is_selected:
		ghost.set_selected(true)
	_drag_layer.add_child(ghost)
	ghost.global_position = rect.position - Vector2(0.0, DRAG_LIFT_PX)
	ghost.size = rect.size
	ghost.pivot_offset = rect.size * 0.5
	_drag_card_view = ghost

	var tween := create_tween()
	tween.tween_property(ghost, "scale", Vector2.ONE * DRAG_SCALE, 0.06)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if _drag_indices.size() > 1:
		_drag_badge = PanelContainer.new()
		_drag_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = COLOR_RED
		badge_style.set_corner_radius_all(10)
		_drag_badge.add_theme_stylebox_override("panel", badge_style)
		_drag_badge.anchor_left = 1.0
		_drag_badge.anchor_right = 1.0
		_drag_badge.offset_left = -34.0
		_drag_badge.offset_right = -2.0
		_drag_badge.offset_top = -10.0
		_drag_badge.offset_bottom = 18.0

		var badge_label := Label.new()
		badge_label.text = "+%d" % (_drag_indices.size() - 1)
		badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_label.add_theme_font_size_override("font_size", 22)
		badge_label.add_theme_color_override("font_color", Color.WHITE)
		_drag_badge.add_child(badge_label)

		ghost.add_child(_drag_badge)

## Updates the floating drag preview's position to follow the pointer, applies
## green/red drop-target highlighting on hovered melds/the Tisch area, and (for
## single-card drags) re-runs the FLIP "make way" preview for hand reordering.
func _on_card_dragged(hand_index: int, global_pos: Vector2) -> void:
	if not _drag_active or _drag_card_view == null or not is_instance_valid(_drag_card_view):
		return

	_drag_card_view.global_position = global_pos - _drag_card_view.size * 0.5 - Vector2(0.0, DRAG_LIFT_PX)

	var hand := game_state.get_human_hand()
	var drag_cards: Array = []
	for i in _drag_indices:
		drag_cards.append(hand[i])

	var hovered_meld_index := -1
	for i in range(_meld_buttons.size()):
		var btn := _meld_buttons[i]
		if is_instance_valid(btn) and btn.get_global_rect().has_point(global_pos):
			hovered_meld_index = i
			break

	var hovered_table := hovered_meld_index < 0 and tisch_area.get_global_rect().has_point(global_pos)

	if hovered_meld_index != _drag_hover_meld_index or hovered_table != _drag_hover_table:
		_clear_drag_hover()
		_drag_hover_meld_index = hovered_meld_index
		_drag_hover_table = hovered_table

		if hovered_meld_index >= 0:
			var meld_entry: Dictionary = game_state.table_melds[hovered_meld_index]
			var combined: Array = []
			for c in meld_entry.get("cards", []):
				combined.append(c)
			for c in drag_cards:
				combined.append(c)
			_drag_hover_valid = (game_state.human_has_melded and game_state.is_human_turn()
				and game_state.human_has_drawn and not game_state.game_over
				and (RummyRules.is_valid_group(combined) or RummyRules.is_valid_run(combined)))
			_set_meld_drop_highlight(hovered_meld_index,
				DropHighlight.VALID if _drag_hover_valid else DropHighlight.INVALID)
		elif hovered_table:
			_drag_hover_valid = (_drag_indices.size() >= 3 and game_state.is_human_turn()
				and game_state.human_has_drawn and not game_state.game_over
				and (RummyRules.is_valid_group(drag_cards) or RummyRules.is_valid_run(drag_cards))
				and (game_state.human_has_melded
					or RummyRules.meld_score(drag_cards) >= GameState.FIRST_MELD_MIN_POINTS))
			_set_tisch_drop_highlight(DropHighlight.VALID if _drag_hover_valid else DropHighlight.INVALID)
		else:
			_drag_hover_valid = false

	if _drag_indices.size() == 1:
		var target_slot := _drag_from_index
		if hovered_meld_index < 0 and not hovered_table and player_hand_area.get_global_rect().has_point(global_pos):
			var local_x := global_pos.x - player_hand_area.get_global_rect().position.x
			var count := _card_views.size()
			target_slot = clampi(roundi((local_x - CARD_WIDTH * 0.5) / maxf(_drag_hand_step, 1.0)), 0, count - 1)
		_update_hand_reorder_preview(target_slot)

## Recomputes and animates the "make way" FLIP offsets for every other hand
## card so they smoothly shift toward the slots they'd occupy if the dragged
## card (single-card drags only) were dropped at target_slot.
func _update_hand_reorder_preview(target_slot: int) -> void:
	if target_slot == _drag_target_slot:
		return
	_drag_target_slot = target_slot

	if _drag_reorder_tween != null and _drag_reorder_tween.is_valid():
		_drag_reorder_tween.kill()

	var count := _card_views.size()
	var order: Array[int] = []
	for h in range(count):
		if h != _drag_from_index:
			order.append(h)
	order.insert(clampi(target_slot, 0, order.size()), _drag_from_index)

	_drag_reorder_tween = create_tween()
	_drag_reorder_tween.set_parallel(true)
	for h in range(count):
		if h == _drag_from_index:
			continue
		var card_view := _card_views[h]
		if not is_instance_valid(card_view):
			continue
		var delta := float(order.find(h) - h) * _drag_hand_step
		_drag_reorder_tween.tween_property(card_view, "offset_left", delta, DRAG_REORDER_TWEEN_SEC)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_drag_reorder_tween.tween_property(card_view, "offset_right", delta, DRAG_REORDER_TWEEN_SEC)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Resets any meld/Tisch drop-highlight back to normal.
func _clear_drag_hover() -> void:
	if _drag_hover_meld_index >= 0:
		_set_meld_drop_highlight(_drag_hover_meld_index, DropHighlight.NONE)
	if _drag_hover_table:
		_set_tisch_drop_highlight(DropHighlight.NONE)

## Swaps the Tisch area's panel style between normal and the precomputed
## green/red drop-highlight variants.
func _set_tisch_drop_highlight(state: DropHighlight) -> void:
	var style := _tisch_style_normal
	if state == DropHighlight.VALID:
		style = _tisch_style_valid
	elif state == DropHighlight.INVALID:
		style = _tisch_style_invalid
	tisch_area.add_theme_stylebox_override("panel", style)

## Updates selected_card_indices so the same logical cards stay selected after
## human_reorder_hand moves the card at from_index to to_index.
func _remap_selection_after_reorder(from_index: int, to_index: int) -> void:
	for j in range(selected_card_indices.size()):
		var i: int = selected_card_indices[j]
		if i == from_index:
			selected_card_indices[j] = to_index
		elif from_index < to_index and i > from_index and i <= to_index:
			selected_card_indices[j] = i - 1
		elif to_index < from_index and i >= to_index and i < from_index:
			selected_card_indices[j] = i + 1

## Cancels any drag currently in progress without performing its action:
## restores dimmed/hidden hand cards and FLIP-preview offsets, clears drop
## highlights, removes the floating ghost, and resets all _drag_* state.
## Called both to finish a drag (the caller applies its own outcome
## afterwards) and as a guard when a new drag starts before the previous
## one's drag_ended arrived, so its ghost can never be orphaned in
## _drag_layer.
func _cancel_active_drag() -> void:
	if not _drag_active:
		return

	_clear_drag_hover()

	for card_view in _card_views:
		if is_instance_valid(card_view):
			card_view.modulate.a = 1.0
			card_view.offset_left = 0.0
			card_view.offset_right = 0.0

	if _drag_reorder_tween != null and _drag_reorder_tween.is_valid():
		_drag_reorder_tween.kill()
	_drag_reorder_tween = null

	if is_instance_valid(_drag_card_view):
		_drag_layer.remove_child(_drag_card_view)
		_drag_card_view.free()

	_drag_active = false
	_drag_card_view = null
	_drag_badge = null
	_drag_from_index = -1
	_drag_indices = []
	_drag_target_slot = -1
	_drag_hover_meld_index = -1
	_drag_hover_table = false
	_drag_hover_valid = false

## Finalizes a hand-card drag: extends/lays a meld if dropped on a valid
## target, reorders the hand if dropped on a new hand position, or snaps back
## to the original layout otherwise. Always cleans up the floating preview and
## any highlight state.
func _on_card_drag_ended(hand_index: int, global_pos: Vector2) -> void:
	if not _drag_active:
		return

	var meld_index := _drag_hover_meld_index
	var hover_table := _drag_hover_table
	var hover_valid := _drag_hover_valid
	var indices := _drag_indices.duplicate()
	var from_index := _drag_from_index
	var target_slot := _drag_target_slot

	_cancel_active_drag()

	var acted := false
	if meld_index >= 0 and hover_valid:
		acted = game_state.human_extend_meld(meld_index, indices)
	elif hover_table and hover_valid:
		acted = game_state.human_lay_meld(indices)
	elif indices.size() == 1 and target_slot != from_index:
		game_state.human_reorder_hand(from_index, target_slot)
		_remap_selection_after_reorder(from_index, target_slot)

	if acted:
		_clear_selection()

	_refresh_ui()

## Tapping anywhere outside the cards/buttons/melds (i.e. directly on the
## background) deselects the current selection.
func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_deselect_all()

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

	# Action buttons — always visible (fixed height row), disabled + dimmed
	# when not relevant to the current phase.
	_set_button_state(meldung_legen_button, count >= 3 and drawn and is_human and not over)
	_set_button_state(anlegen_button, count >= 1 and has_target and drawn
							  and is_human and game_state.human_has_melded and not over)
	_set_button_state(abwerfen_button, count == 1 and drawn and is_human and not over)

	_style_button(meldung_legen_button, COLOR_GREEN)
	_style_button(anlegen_button, COLOR_ACCENT_BLUE)
	_style_button(abwerfen_button, COLOR_RED)

func _refresh_ui() -> void:
	_render_header()
	_render_phase_indicator()
	_render_hand()
	_render_table()
	_render_tisch()
	_render_opponent_areas()
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

## Updates the top header bar: own penalty points (if the round ended right
## now), the opponent's points (only shown when there's a single opponent),
## and the round counter. Own points turn orange once they exceed
## HIGH_PENALTY_THRESHOLD, green otherwise; round/opponent stay white.
func _render_header() -> void:
	var player_points: int = game_state.get_human_penalty_points()

	header_player_label.text = "Spieler: %d Punkte" % player_points
	header_round_label.text = "Runde %d" % game_state.round_number
	header_round_label.add_theme_color_override("font_color", HEADER_TEXT_COLOR)

	if game_state.num_opponents == 1:
		header_opponent_label.visible = true
		header_opponent_label.text = "Gegner: %d Punkte" % game_state.get_bot_penalty_points(1)
		header_opponent_label.add_theme_color_override("font_color", HEADER_TEXT_COLOR)
	else:
		header_opponent_label.visible = false

	var player_color: Color = SCORE_COLOR_HIGH if player_points > HIGH_PENALTY_THRESHOLD else SCORE_COLOR_LOW
	header_player_label.add_theme_color_override("font_color", player_color)

# ── Hand rendering ────────────────────────────────────────────────────────────

func _render_hand() -> void:
	_card_views.clear()
	_card_slots.clear()
	for child in player_hand_area.get_children():
		child.queue_free()

	var hand := game_state.get_human_hand()
	var slot_height: float = CARD_HEIGHT + SELECTION_LIFT_PX
	var count := hand.size()

	# Cards always span the full width of PlayerHandArea: spread out evenly
	# with a gap (positive separation) if they fit at full size, or overlap
	# evenly (negative separation) if there are too many to fit.
	var available_width: float = player_hand_area.size.x
	if available_width <= 0.0:
		available_width = get_viewport_rect().size.x - HORIZONTAL_MARGIN
	var separation: float = 0.0
	if count > 1:
		separation = (available_width - count * CARD_WIDTH) / float(count - 1)
	player_hand_area.add_theme_constant_override("separation", roundi(separation))
	_drag_hand_step = CARD_WIDTH + separation

	for hand_index in range(count):
		# Each card slot is a plain Control — NOT a Container.
		# The CardView is positioned inside using anchors + offsets.
		# Changing offset_top/offset_bottom during animation never touches
		# custom_minimum_size, so the layout engine is never re-triggered.
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(CARD_WIDTH, slot_height)
		player_hand_area.add_child(slot)
		_card_slots.append(slot)

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
		card_view.drag_started.connect(_on_card_drag_started)
		card_view.card_dragged.connect(_on_card_dragged)
		card_view.drag_ended.connect(_on_card_drag_ended)
		if is_sel:
			card_view.set_selected(true)
		_card_views.append(card_view)

# ── Table rendering ───────────────────────────────────────────────────────────

func _render_table() -> void:
	for child in table_area.get_children():
		child.queue_free()

	var can_draw: bool = game_state.is_human_turn() and not game_state.human_has_drawn and not game_state.game_over

	deck_pile_view = _build_deck_pile_view(can_draw)
	table_area.add_child(deck_pile_view)

	discard_pile_view = _build_discard_pile_view(can_draw)
	table_area.add_child(discard_pile_view)

## Wires up `stack` (a deck/discard pile's card stack) so it can be tapped to
## draw a card while `can_draw` is true: adds a pulsing gold glow behind it
## and scales up slightly on hover/touch as visual feedback. Outside the draw
## phase the pile stays purely decorative — no glow, and taps do nothing.
func _setup_pile_interaction(stack: Control, pile_size: Vector2, can_draw: bool, on_pressed: Callable) -> void:
	stack.pivot_offset = pile_size * 0.5
	if not can_draw:
		return

	var glow := Panel.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	glow_style.set_corner_radius_all(8)
	glow_style.shadow_color = PILE_GLOW_COLOR
	glow_style.shadow_size = PILE_GLOW_SHADOW_SIZE
	glow.add_theme_stylebox_override("panel", glow_style)
	stack.add_child(glow)
	stack.move_child(glow, 0)

	var pulse := create_tween()
	pulse.set_loops()
	pulse.tween_property(glow, "modulate:a", 0.4, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(glow, "modulate:a", 1.0, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	stack.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	stack.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_pressed.call())
	stack.mouse_entered.connect(func() -> void:
		create_tween().tween_property(stack, "scale", Vector2.ONE * PILE_HOVER_SCALE, 0.1))
	stack.mouse_exited.connect(func() -> void:
		create_tween().tween_property(stack, "scale", Vector2.ONE, 0.1))

## Builds the deck pile: a title above a stack of face-down CardBack visuals —
## two faint, offset "shadow" cards behind a front card that also shows the
## remaining card count.
func _build_deck_pile_view(can_draw: bool) -> Control:
	var outer := VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	outer.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Deck"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
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
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(shadow)

	var front := CardBack.new()
	front.size = Vector2(PILE_CARD_WIDTH, PILE_CARD_HEIGHT)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(front)

	var count_label := Label.new()
	count_label.text = "%d" % game_state.draw_deck.size()
	count_label.add_theme_font_size_override("font_size", 44)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.add_child(count_label)

	_setup_pile_interaction(stack, stack.custom_minimum_size, can_draw, _on_deck_pile_pressed)
	return outer

## Builds the discard pile: a title above a stack with the top card shown
## fully (correct color/suit via CardView) and faint cream cards behind it.
func _build_discard_pile_view(can_draw: bool) -> Control:
	var outer := VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	outer.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Ablage"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
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
			shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty.add_theme_stylebox_override("panel", _build_card_face_style())
		stack.add_child(empty)

	_setup_pile_interaction(stack, stack.custom_minimum_size, can_draw and top_card != null, _on_discard_pile_pressed)
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

## Colorful joker card-face style (matches CardView's joker hand-card look).
func _build_joker_card_face_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CardView.JOKER_BG_COLOR
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = CardView.JOKER_BORDER_COLOR
	return style

# ── Opponent area rendering ──────────────────────────────────────────────────

## Rebuilds the opponent area as 1 or 2 rows of opponent slots, depending on
## num_opponents:
##   1 -> [[1]]          one full-width slot
##   2 -> [[1, 2]]       one row, two compact slots
##   3 -> [[1, 2], [3]]  two rows, second row has one centered compact slot
##   4 -> [[1, 2], [3, 4]]  two rows of two compact slots
func _render_opponent_areas() -> void:
	for child in opponent_area.get_children():
		child.queue_free()
	_opponent_hand_areas.clear()

	var n := game_state.num_opponents
	var compact := n > 1
	opponent_area.add_theme_constant_override("separation", int(OPPONENT_ROW_GAP))

	var row_height: float = OPPONENT_ROW_HEIGHT_SINGLE if not compact else OPPONENT_ROW_HEIGHT_COMPACT
	var num_rows: int = 1 if n <= 2 else 2
	opponent_area.custom_minimum_size = Vector2(0, num_rows * row_height + (num_rows - 1) * OPPONENT_ROW_GAP)

	var available_width: float = opponent_area.size.x
	if available_width <= 0.0:
		available_width = get_viewport_rect().size.x - HORIZONTAL_MARGIN
	var two_col_width: float = (available_width - OPPONENT_ROW_GAP) / 2.0

	var rows: Array = [[1]]
	match n:
		2: rows = [[1, 2]]
		3: rows = [[1, 2], [3]]
		4: rows = [[1, 2], [3, 4]]

	for row_bots in rows:
		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", int(OPPONENT_ROW_GAP))
		row_box.custom_minimum_size = Vector2(0, row_height)
		if row_bots.size() == 1 and n != 1:
			row_box.alignment = BoxContainer.ALIGNMENT_CENTER
		opponent_area.add_child(row_box)

		for bot_number in row_bots:
			row_box.add_child(_build_opponent_slot(bot_number, two_col_width, row_height, compact, n))

## Builds one opponent's panel: name + card-count badge header, and a row of
## face-down cards sized to fill the slot without colliding with neighbors.
func _build_opponent_slot(bot_number: int, two_col_width: float, row_height: float, compact: bool, n: int) -> PanelContainer:
	var player_index := bot_number

	var panel := PanelContainer.new()
	panel.clip_contents = true
	if n == 1:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		panel.custom_minimum_size = Vector2(two_col_width, row_height)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if (n == 3 and bot_number == 3) else Control.SIZE_FILL
	panel.custom_minimum_size.y = row_height

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_BG
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8 if compact else 10)
	if game_state.current_player_index == player_index and not game_state.game_over:
		style.border_color = OPPONENT_ACTIVE_BORDER_COLOR
		style.set_border_width_all(OPPONENT_ACTIVE_BORDER_WIDTH)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var name_label := Label.new()
	name_label.text = game_state.get_player_name(player_index)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size",
		OPPONENT_NAME_FONT_SIZE_SINGLE if not compact else OPPONENT_NAME_FONT_SIZE_COMPACT)
	header.add_child(name_label)

	var badge_size: float = OPPONENT_BADGE_SIZE_SINGLE if not compact else OPPONENT_BADGE_SIZE_COMPACT
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(badge_size, badge_size)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.8, 0.2, 0.2)
	badge_style.set_corner_radius_all(int(badge_size / 2.0))
	badge.add_theme_stylebox_override("panel", badge_style)
	header.add_child(badge)

	var badge_label := Label.new()
	badge_label.text = "%d" % game_state.get_player_hand_count(player_index)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size",
		OPPONENT_BADGE_FONT_SIZE_SINGLE if not compact else OPPONENT_BADGE_FONT_SIZE_COMPACT)
	badge.add_child(badge_label)

	var hand_area := HBoxContainer.new()
	hand_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hand_area)

	var slot_width: float = two_col_width if n != 1 else (get_viewport_rect().size.x - HORIZONTAL_MARGIN)
	_fill_opponent_hand_area(hand_area, player_index, slot_width, compact)

	while _opponent_hand_areas.size() < bot_number:
		_opponent_hand_areas.append(null)
	_opponent_hand_areas[bot_number - 1] = hand_area

	return panel

## Fills hand_area with one face-down card per card in player_index's hand,
## spreading them across slot_width (or overlapping, down to a min separation,
## if there are too many to fit at full size).
func _fill_opponent_hand_area(hand_area: Control, player_index: int, slot_width: float, compact: bool) -> void:
	for child in hand_area.get_children():
		child.queue_free()

	var card_w: float = OPPONENT_CARD_WIDTH_COMPACT if compact else OPPONENT_CARD_WIDTH_SINGLE
	var card_h: float = OPPONENT_CARD_HEIGHT_COMPACT if compact else OPPONENT_CARD_HEIGHT_SINGLE
	var slot_padding: float = 16.0 if compact else 20.0 # 2x panel content margin
	var available: float = slot_width - slot_padding

	var count := game_state.get_player_hand_count(player_index)
	var separation: float = 0.0
	if count > 1:
		# No lower bound: always shrink to fit available width, however much
		# overlap that requires, so this row never grows wider than its slot
		# (which would push the whole layout wider than the screen).
		separation = (available - count * card_w) / float(count - 1)
	hand_area.add_theme_constant_override("separation", roundi(separation))

	for _i in range(count):
		hand_area.add_child(_build_card_back(Vector2(card_w, card_h)))

## Builds a small face-down card visual (used for opponent hand rows and for
## the bot draw/discard flying-card animation).
func _build_card_back(card_size: Vector2 = Vector2(OPPONENT_CARD_WIDTH_SINGLE, OPPONENT_CARD_HEIGHT_SINGLE)) -> Control:
	var back := CardBack.new()
	back.custom_minimum_size = card_size
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return back

## Returns the global anchor point (right edge, vertical center) of the given
## bot's hand area, for the flying-card animation. Falls back to the screen
## center if the slot hasn't been built yet.
func _get_opponent_anchor(player_index: int) -> Vector2:
	var idx := player_index - 1
	if idx < 0 or idx >= _opponent_hand_areas.size():
		return get_viewport_rect().size * 0.5
	var hand_area := _opponent_hand_areas[idx]
	if hand_area == null or not is_instance_valid(hand_area):
		return get_viewport_rect().size * 0.5
	var rect := hand_area.get_global_rect()
	return rect.position + Vector2(rect.size.x, rect.size.y * 0.5)

# ── Bot turn animation ────────────────────────────────────────────────────────

## Spawns a small card visual that flies from from_global to to_global and
## fades out, then frees itself. Purely decorative — game state is already
## updated by the time this plays.
func _spawn_flying_card(from_global: Vector2, to_global: Vector2) -> void:
	var card := _build_card_back(FLYING_CARD_SIZE)
	card.size = FLYING_CARD_SIZE
	card.z_index = 100
	add_child(card)
	card.global_position = from_global

	var tween := create_tween()
	tween.tween_property(card, "global_position", to_global, 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(card, "modulate:a", 0.0, 0.15).set_delay(0.1)
	tween.tween_callback(card.queue_free)

# ── Tisch (table melds) rendering ────────────────────────────────────────────

## Renders all table melds as horizontal, slightly-overlapping card groups in
## the scrollable MeldsRow. Shows EmptyMeldsLabel instead when there are none.
func _render_tisch() -> void:
	for child in melds_row.get_children():
		child.queue_free()
	_meld_buttons.clear()

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

	_apply_meld_button_style(btn, meld_index, is_own, DropHighlight.NONE)

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

	var substitutes := RummyRules.get_joker_substitutes(cards)
	var swap_active := _joker_swap_mode_active()
	var swap_card := _selected_swap_card()
	for i in range(cards.size()):
		var card: Card = cards[i]
		var substitute: Card = substitutes[i]
		if card.is_joker and swap_active:
			var swap_match := (swap_card != null and not swap_card.is_joker
				and substitute != null
				and substitute.suit == swap_card.suit and substitute.rank == swap_card.rank)
			hbox.add_child(_build_table_joker_button(card, substitute, meld_index, i, swap_match))
		else:
			hbox.add_child(_build_mini_card(card, substitute if card.is_joker else null))

	btn.pressed.connect(_on_meld_tapped.bind(meld_index))
	_meld_buttons.append(btn)
	return btn

## Builds and applies a table meld button's stylebox: neutral/reddish
## background depending on ownership, a green border when selected for
## Anlegen, and (while a card is being dragged over it) an outer green/red
## drop-highlight border that takes precedence over the selection border.
func _apply_meld_button_style(btn: Button, meld_index: int, is_own: bool, drop_state: DropHighlight) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.3) if is_own else Color(0.32, 0.22, 0.22)
	style.set_corner_radius_all(6)
	if drop_state == DropHighlight.VALID:
		style.border_color = DROP_VALID_COLOR
		style.set_border_width_all(DROP_HIGHLIGHT_BORDER_WIDTH)
	elif drop_state == DropHighlight.INVALID:
		style.border_color = DROP_INVALID_COLOR
		style.set_border_width_all(DROP_HIGHLIGHT_BORDER_WIDTH)
	elif meld_index == selected_meld_index or _meld_extension_hint_valid(meld_index):
		style.border_color = Color(0.2, 0.9, 0.2)
		style.set_border_width_all(3)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

## Applies a drag-drop highlight border to the given table meld, or clears it
## back to its normal/selected styling when state is NONE.
func _set_meld_drop_highlight(meld_index: int, state: DropHighlight) -> void:
	if meld_index < 0 or meld_index >= _meld_buttons.size():
		return
	var entry: Dictionary = game_state.table_melds[meld_index]
	var is_own: bool = entry.get("owner", GameState.HUMAN_INDEX) == GameState.HUMAN_INDEX
	_apply_meld_button_style(_meld_buttons[meld_index], meld_index, is_own, state)

## True if the currently selected hand cards, added to the meld at
## meld_index, would form a valid extension (group or run, possibly with a
## joker filling a gap) — used to preview which melds could be extended with
## the current selection before the player taps one (green border hint).
func _meld_extension_hint_valid(meld_index: int) -> bool:
	if selected_card_indices.is_empty():
		return false
	if not (game_state.human_has_melded and game_state.is_human_turn()
			and game_state.human_has_drawn and not game_state.game_over):
		return false
	if meld_index < 0 or meld_index >= game_state.table_melds.size():
		return false

	var hand := game_state.get_human_hand()
	var meld_entry: Dictionary = game_state.table_melds[meld_index]
	var combined: Array = []
	for c in meld_entry.get("cards", []):
		combined.append(c)
	for i in selected_card_indices:
		if i < 0 or i >= hand.size():
			return false
		combined.append(hand[i])

	return RummyRules.is_valid_group(combined) or RummyRules.is_valid_run(combined)

## True while exactly one hand card is selected and the human could use it for
## a Joker-Tausch (own first meld already laid, human's turn, game not over).
## Drives whether table jokers render as clickable swap targets.
func _joker_swap_mode_active() -> bool:
	return selected_card_indices.size() == 1 \
		and game_state.human_has_melded \
		and game_state.is_human_turn() \
		and not game_state.game_over

## Returns the single selected hand card when _joker_swap_mode_active(), or
## null otherwise.
func _selected_swap_card() -> Card:
	if selected_card_indices.size() != 1:
		return null
	var hand := game_state.get_human_hand()
	var i: int = selected_card_indices[0]
	if i < 0 or i >= hand.size():
		return null
	return hand[i]

## Builds a clickable joker mini-card for Joker-Tausch. If swap_match (the
## selected hand card is the real card this joker represents), it pulses
## green and tapping it performs the swap. Otherwise tapping it gives a brief
## red "invalid" flash.
func _build_table_joker_button(card: Card, substitute: Card, meld_index: int, joker_index: int, swap_match: bool) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(MELD_CARD_WIDTH, MELD_CARD_HEIGHT)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.text = ""

	var style := _build_joker_card_face_style()
	if swap_match:
		style.border_color = DROP_VALID_COLOR
		style.set_border_width_all(DROP_HIGHLIGHT_BORDER_WIDTH)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	btn.add_child(vbox)

	var label := Label.new()
	label.text = "JOKER"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", CardView.JOKER_TEXT_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(label)

	if substitute != null:
		var sub_label := Label.new()
		sub_label.text = "= %s" % substitute.to_display_string()
		sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_label.add_theme_font_size_override("font_size", 18)
		var sub_is_red := substitute.suit == Card.Suit.HEARTS or substitute.suit == Card.Suit.DIAMONDS
		sub_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6) if sub_is_red else Color(0.85, 0.85, 0.85))
		sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(sub_label)

	if swap_match:
		_start_joker_swap_pulse(btn)

	btn.pressed.connect(_on_table_joker_tapped.bind(meld_index, joker_index, btn, style))
	return btn

## Loops a green pulse on a table joker that the current hand selection could
## be swapped for, drawing attention to the valid Joker-Tausch target.
func _start_joker_swap_pulse(btn: Button) -> void:
	btn.modulate = Color.WHITE
	var tween := btn.create_tween()
	tween.set_loops()
	tween.tween_property(btn, "modulate", JOKER_SWAP_PULSE_COLOR, JOKER_SWAP_PULSE_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(btn, "modulate", Color.WHITE, JOKER_SWAP_PULSE_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Handles a tap on a table joker while _joker_swap_mode_active(): performs
## the Joker-Tausch if the selected hand card matches this joker's
## substitute, otherwise flashes the joker red briefly.
func _on_table_joker_tapped(meld_index: int, joker_index: int, btn: Button, normal_style: StyleBoxFlat) -> void:
	if selected_card_indices.size() != 1:
		return
	var hand_index: int = selected_card_indices[0]
	if game_state.human_swap_joker(meld_index, hand_index, joker_index):
		_clear_selection()
		_refresh_ui()
	else:
		_flash_joker_invalid(btn, normal_style)

## Briefly flashes a red border on an ineligible table joker after an invalid
## Joker-Tausch tap, then restores its previous style.
func _flash_joker_invalid(btn: Button, normal_style: StyleBoxFlat) -> void:
	var flash_style := normal_style.duplicate()
	flash_style.border_color = DROP_INVALID_COLOR
	flash_style.set_border_width_all(DROP_HIGHLIGHT_BORDER_WIDTH)
	btn.add_theme_stylebox_override("normal", flash_style)
	btn.add_theme_stylebox_override("hover", flash_style)
	btn.add_theme_stylebox_override("pressed", flash_style)

	var tween := btn.create_tween()
	tween.tween_interval(JOKER_SWAP_INVALID_FLASH_SEC)
	tween.tween_callback(func():
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", normal_style)
		btn.add_theme_stylebox_override("pressed", normal_style))

## Builds a small, non-interactive card visual used inside a meld group, with
## the same cream face and red/dark suit colors as the hand cards. For a
## joker, substitute is the card it represents within this meld (shown as a
## small "= 6♥" label) or null if it couldn't be determined.
func _build_mini_card(card: Card, substitute: Card = null) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(MELD_CARD_WIDTH, MELD_CARD_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if card.is_joker:
		panel.add_theme_stylebox_override("panel", _build_joker_card_face_style())

		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(vbox)

		var label := Label.new()
		label.text = "JOKER"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", CardView.JOKER_TEXT_COLOR)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(label)

		if substitute != null:
			var sub_label := Label.new()
			sub_label.text = "= %s" % substitute.to_display_string()
			sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sub_label.add_theme_font_size_override("font_size", 22)
			var sub_is_red := substitute.suit == Card.Suit.HEARTS or substitute.suit == Card.Suit.DIAMONDS
			sub_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6) if sub_is_red else Color(0.85, 0.85, 0.85))
			sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(sub_label)

		return panel

	panel.add_theme_stylebox_override("panel", _build_card_face_style())

	var label := Label.new()
	label.text = card.to_display_string()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	var is_red := card.suit == Card.Suit.HEARTS or card.suit == Card.Suit.DIAMONDS
	label.add_theme_color_override("font_color", Color(0.8, 0.0, 0.0) if is_red else Color(0.133, 0.133, 0.133))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	return panel
