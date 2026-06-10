class_name CardBack
extends Control

## Face-down card visual: dark blue background, white border, and a diagonal
## diamond-hatch pattern. Used for the opponent's hand, the deck pile, and the
## bot draw/discard "flying card" animation. Everything is drawn manually in
## _draw() (background, border, and pattern, in that order) so the pattern is
## guaranteed to render on top.

const BG_COLOR := Color(0.102, 0.227, 0.431) # #1a3a6e
const BORDER_COLOR := Color(1.0, 1.0, 1.0)
const PATTERN_COLOR := Color(1.0, 1.0, 1.0, 0.18)
const CORNER_RADIUS := 6
const BORDER_WIDTH := 2.0
const PATTERN_SPACING := 10.0

func _ready() -> void:
	clip_contents = true
	resized.connect(queue_redraw)

func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.set_corner_radius_all(CORNER_RADIUS)
	style.set_border_width_all(int(BORDER_WIDTH))
	style.border_color = BORDER_COLOR
	draw_style_box(style, Rect2(Vector2.ZERO, size))

	_draw_diagonals(1)
	_draw_diagonals(-1)

## Draws a set of evenly-spaced diagonal lines across the card to form a
## diamond/hatch pattern when combined with the opposite direction.
func _draw_diagonals(direction: int) -> void:
	var w := size.x
	var h := size.y
	var diag := w + h
	var i := -h
	while i < diag:
		var p1: Vector2
		var p2: Vector2
		if direction > 0:
			p1 = Vector2(i, 0.0)
			p2 = Vector2(i + h, h)
		else:
			p1 = Vector2(w - i, 0.0)
			p2 = Vector2(w - i - h, h)
		draw_line(p1, p2, PATTERN_COLOR, 1.0)
		i += PATTERN_SPACING
