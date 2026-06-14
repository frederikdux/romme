class_name JokerPlaceholder
extends Control

## Dashed, pulsing gold "+" drop target shown beside a table run meld when the
## current hand selection (a Joker, optionally combined with another card)
## could be attached there to extend the run. Emits `tapped` on click; the
## screen also treats this control as a drag-and-drop target.

signal tapped

const GLOW_COLOR := Color(1.0, 0.84, 0.0) # gold
const DIM_COLOR := Color(1.0, 0.84, 0.0, 0.35)
const DASH_LENGTH := 6.0
const BORDER_WIDTH := 3.0
const PULSE_DURATION := 0.6
const PLUS_FONT_SIZE := 48

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color.WHITE
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(self, "modulate", GLOW_COLOR, PULSE_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate", DIM_COLOR, PULSE_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var corners := [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	for i in range(4):
		draw_dashed_line(corners[i], corners[(i + 1) % 4], GLOW_COLOR, BORDER_WIDTH, DASH_LENGTH, true)

	var font := ThemeDB.fallback_font
	var text := "+"
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, PLUS_FONT_SIZE).x
	var baseline := Vector2(
		(size.x - text_width) * 0.5,
		size.y * 0.5 + PLUS_FONT_SIZE * 0.35
	)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_FONT_SIZE, GLOW_COLOR)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		tapped.emit()
