# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A Godot 4.6 (GDScript only, no .NET/C#) 2D Rommé (Rummy) card game prototype targeting mobile
("Mobile" rendering method, portrait viewport 1080x1920). UI text is in German.

## Commands

- This is a Godot project — there is no CLI build/test runner in this environment (no `godot`
  binary available). Open `project.godot` in the Godot 4.6 editor to run the game
  (`scenes/main.tscn` is the main scene) or to check scripts for errors.
- There is no automated test suite. Verify changes by reasoning through `GameState`/`RummyRules`
  logic manually and, where possible, by running the project in the Godot editor.

## Architecture

### Hard rule: core/rules must stay UI-free

`scripts/core/` (`Card`, `Deck`, `Player`, `GameState`) and `scripts/rules/` (`RummyRules`) must
never depend on Godot UI classes (`Control`, `Button`, etc.) — they're plain `RefCounted` data +
logic so the game rules stay testable/portable. All Godot/UI code lives in `scripts/ui/`, which
reads from `GameState` and calls its methods, then re-renders. When adding a feature, add the
logic to `GameState`/`RummyRules` first; UI scripts only orchestrate rendering and forward input.

### GameState (`scripts/core/game_state.gd`)

The single source of truth for a match, owned by `GameScreen` (`scripts/ui/game_screen.gd`).

- `players[0]` is the human ("Du"); `players[1..num_opponents]` are bots ("Gegner 1".."Gegner N").
  `HUMAN_INDEX = 0`, `1 <= num_opponents <= MAX_OPPONENTS (4)`.
- Turn order cycles through `players` in index order. Per-turn flag `human_has_drawn` gates the
  human's phases:
  1. **Draw** — `human_draw_from_deck()` / `human_draw_from_discard()`
  2. **Meld** (optional, repeatable) — `human_lay_meld()`, `human_extend_meld()`,
     `human_swap_joker()` (Joker-Tausch)
  3. **Discard** — `human_discard_card()` → advances to the next player
- First meld (own or any bot's) must reach `FIRST_MELD_MIN_POINTS` (40), tracked via
  `human_has_melded` / `bot_has_melded[i]` (indexed by `player_index - 1`).
- `table_melds` is `Array` of `{"owner": player_index, "cards": Array[Card]}`.
- **Bot turns are step-based** so the UI can pace/animate each step individually: call
  `bot_draw_step()`, then `bot_meld_step()` repeatedly until `laid == false`, then
  `bot_extend_step()` repeatedly until `extended == false`, then `bot_discard_step()`
  (which also calls `_check_game_over()` and advances the turn).
- `to_dict()` / `from_dict()` serialize the full state; `SaveGameService`
  (`scripts/persistence/save_game_service.gd`) reads/writes this as JSON to `user://savegame.json`
  but is not yet wired into the UI.

### RummyRules (`scripts/rules/rummy_rules.gd`)

Static helpers only, operate on untyped `Array` (so they work with both `Array[Card]` and
dictionary-sourced arrays):

- `is_valid_group(cards)` — 3-4 cards, same rank, distinct suits.
- `is_valid_run(cards)` — 3+ consecutive same-suit cards, ace low or high.
- Both support multiple jokers per meld, as long as non-joker cards outnumber jokers; for runs,
  jokers fill internal single-card gaps or extend either end (never two jokers adjacent).
- `get_joker_substitutes(cards)` — per-card array of the real card each joker represents (used for
  scoring and table display).
- `meld_score(cards)` / `calculate_hand_points(hand)` — scoring (joker counts as its substitute in
  a meld, but as 20 points as a penalty card in hand).
- `order_meld_cards(cards)` — reorders a valid meld for table display (groups by suit, runs by
  rank, jokers placed at their substitute's position).
- `get_run_attach_sides(meld_cards, extra_cards)` — whether a joker (+ optional extra cards) could
  extend a table run at its low/high end (drives the "+" Joker-Anlegen placeholders in the UI).

### UI (`scripts/ui/game_screen.gd`)

Single large script driving `scenes/screens/game_screen.tscn`. Key patterns to follow:

- `_require_node(name)` does a recursive `find_child` lookup and fails loudly (`push_error` +
  `assert`) if a required scene node is missing — use this for any new required node.
- Render functions (`_render_hand`, `_render_table`, `_render_tisch`,
  `_render_opponent_areas`, ...) follow a "clear children, rebuild from `GameState`" pattern,
  called from `_refresh_ui()` after every state-changing action.
- Hand card lift/selection and drag-and-drop animate `offset_top/bottom/left/right` on a plain
  `Control` slot — never tween `custom_minimum_size`/spacer sizes, as that retriggers layout and
  shifts the whole screen (and `add_theme_constant_override` inside a `resized` handler causes
  infinite recursion).
- Gotcha: a brand-new `class_name X extends Control` script referenced from another script in the
  same editing session may not be resolvable by name yet (global class cache lag). Use
  `const XScript: GDScript = preload("res://path/to/x.gd")` and `XScript.new() as Control` instead
  (see `JokerPlaceholderScript` in `game_screen.gd`).
- Bot turns are paced via `_run_bot_turn_sequence()` / `_run_single_bot_turn()`, awaiting timers
  between each `GameState` step call so the UI can animate draws/melds/discards.
