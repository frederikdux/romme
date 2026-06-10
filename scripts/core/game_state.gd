class_name GameState
extends RefCounted

## Owns and mutates all game data for a single match. No Godot UI dependencies —
## UI scripts should call these methods and then re-render from the results.
##
## Turn order (enforced via human_has_drawn flag):
##   1. DRAW    — human_draw_from_deck / human_draw_from_discard
##   2. OPTIONAL — human_lay_meld / human_extend_meld (any number of times)
##   3. DISCARD — human_discard_card  →  switches to bot turn
##
## table_melds entries: {"owner": int, "cards": Array[Card]}

const STARTING_HAND_SIZE := 13
const FIRST_MELD_MIN_POINTS := 40

const HUMAN_INDEX := 0
const BOT_INDEX := 1

var human_player: Player
var bot_player: Player
var draw_deck: Deck
var discard_pile: Array[Card] = []
## Each element is a Dictionary: {"owner": HUMAN_INDEX/BOT_INDEX, "cards": Array}.
var table_melds: Array = []
var current_player_index: int = HUMAN_INDEX

## Per-turn phase flag; reset to false at the start of each human turn.
var human_has_drawn: bool = false
## Set permanently once the human lays their first valid meld (≥40 pts).
var human_has_melded: bool = false
var bot_has_melded: bool = false

var game_over: bool = false
var winner_index: int = -1
var status_text: String = ""

## Incremented by new_game(); the very first game played is round 1.
var round_number: int = 0

func _init() -> void:
	human_player = Player.new("Du")
	bot_player = Player.new("Bot")
	draw_deck = Deck.new()

## Resets all state and deals a fresh game.
func new_game() -> void:
	human_player = Player.new("Du")
	bot_player = Player.new("Bot")
	draw_deck = Deck.new()
	draw_deck.build_standard_deck()
	draw_deck.shuffle_deck()
	discard_pile.clear()
	table_melds.clear()
	human_has_drawn = false
	human_has_melded = false
	bot_has_melded = false
	game_over = false
	winner_index = -1

	for i in range(STARTING_HAND_SIZE):
		human_player.add_card(draw_deck.draw_card())
		bot_player.add_card(draw_deck.draw_card())
	human_player.sort_hand()

	var starting_card := draw_deck.draw_card()
	if starting_card != null:
		discard_pile.append(starting_card)

	current_player_index = HUMAN_INDEX
	status_text = "Dein Zug — ziehe eine Karte vom Deck oder Ablagestapel."
	round_number += 1

func get_human_hand() -> Array[Card]:
	return human_player.hand

## Penalty points the human would incur if the round ended right now
## (sum of unmelded card values still in hand).
func get_human_penalty_points() -> int:
	return RummyRules.calculate_hand_points(human_player.hand)

## Penalty points the bot would incur if the round ended right now.
func get_bot_penalty_points() -> int:
	return RummyRules.calculate_hand_points(bot_player.hand)

func get_top_discard_card() -> Card:
	if discard_pile.is_empty():
		return null
	return discard_pile.back()

func get_status_text() -> String:
	return status_text

func is_human_turn() -> bool:
	return current_player_index == HUMAN_INDEX

# ── Draw ──────────────────────────────────────────────────────────────────────

func human_draw_from_deck() -> bool:
	if not _assert_human_action_allowed():
		return false
	if human_has_drawn:
		status_text = "Du hast bereits eine Karte gezogen."
		return false

	if draw_deck.is_empty():
		_refill_deck_from_discard()
	if draw_deck.is_empty():
		status_text = "Deck und Ablagestapel sind leer — kein Ziehen möglich."
		return false

	var card := draw_deck.draw_card()
	human_player.add_card(card)
	human_has_drawn = true
	status_text = "Du hast %s gezogen. Lege Meldungen oder wirf eine Karte ab." % card.to_display_string()
	return true

func human_draw_from_discard() -> bool:
	if not _assert_human_action_allowed():
		return false
	if human_has_drawn:
		status_text = "Du hast bereits eine Karte gezogen."
		return false
	if discard_pile.is_empty():
		status_text = "Der Ablagestapel ist leer."
		return false

	var card: Card = discard_pile.pop_back()
	human_player.add_card(card)
	human_has_drawn = true
	status_text = "Du hast %s vom Ablagestapel genommen. Lege Meldungen oder wirf eine Karte ab." % card.to_display_string()
	return true

# ── Meld ──────────────────────────────────────────────────────────────────────

## Validates the selected hand indices as a Rommé meld and lays them on the table.
## First meld must reach FIRST_MELD_MIN_POINTS (40). Returns true on success.
func human_lay_meld(indices: Array[int]) -> bool:
	if not _assert_human_drew():
		return false
	if indices.size() < 3:
		status_text = "Mindestens 3 Karten für eine Meldung."
		return false

	var selected: Array[Card] = []
	for i in indices:
		if i < 0 or i >= human_player.hand.size():
			status_text = "Ungültige Kartenauswahl."
			return false
		selected.append(human_player.hand[i])

	if not (RummyRules.is_valid_group(selected) or RummyRules.is_valid_run(selected)):
		status_text = "Keine gültige Meldung!"
		return false

	if not human_has_melded:
		var score := RummyRules.meld_score(selected)
		if score < FIRST_MELD_MIN_POINTS:
			status_text = "Erstmeldung braucht mindestens %d Punkte — diese hat %d." % [FIRST_MELD_MIN_POINTS, score]
			return false

	_remove_cards_by_indices(human_player, indices)
	table_melds.append({"owner": HUMAN_INDEX, "cards": selected})
	human_has_melded = true

	if _check_game_over():
		return true
	status_text = "Meldung gelegt! Leg weitere Meldungen oder wirf eine Karte ab."
	return true

## Extends an existing table meld with cards from the human's hand.
## Requires the human to have made their own first meld already.
func human_extend_meld(meld_index: int, card_indices: Array[int]) -> bool:
	if not _assert_human_drew():
		return false
	if not human_has_melded:
		status_text = "Du musst erst eine eigene Meldung legen, bevor du anlegen kannst."
		return false
	if meld_index < 0 or meld_index >= table_melds.size():
		status_text = "Ungültige Meldung."
		return false
	if card_indices.is_empty():
		status_text = "Keine Karten ausgewählt."
		return false

	var meld_entry: Dictionary = table_melds[meld_index]
	var existing: Array = meld_entry["cards"]

	var new_cards: Array[Card] = []
	for i in card_indices:
		if i < 0 or i >= human_player.hand.size():
			status_text = "Ungültige Kartenauswahl."
			return false
		new_cards.append(human_player.hand[i])

	# Use untyped array so dict-sourced Card values don't need explicit casting.
	var combined: Array = []
	for c in existing:
		combined.append(c)
	for c in new_cards:
		combined.append(c)

	if not (RummyRules.is_valid_group(combined) or RummyRules.is_valid_run(combined)):
		status_text = "Karte(n) passen nicht an diese Meldung."
		return false

	_remove_cards_by_indices(human_player, card_indices)
	meld_entry["cards"] = combined

	if _check_game_over():
		return true
	status_text = "Erfolgreich angelegt!"
	return true

# ── Discard ───────────────────────────────────────────────────────────────────

## Discards the card at hand_index, ending the human's turn. Returns true on success.
func human_discard_card(hand_index: int) -> bool:
	if not _assert_human_drew():
		return false

	var card := human_player.remove_card_at(hand_index)
	if card == null:
		status_text = "Ungültige Karte."
		return false

	discard_pile.append(card)

	if _check_game_over():
		return true

	status_text = "Du hast %s abgeworfen. Bot ist dran." % card.to_display_string()
	current_player_index = BOT_INDEX
	return true

func human_sort_hand() -> void:
	human_player.sort_hand()

# ── Bot ───────────────────────────────────────────────────────────────────────

## Bot turn: draws a card, lays any valid melds it can (respecting the same
## "first meld ≥ FIRST_MELD_MIN_POINTS" rule as the human), extends existing
## table melds with leftover cards once it has melded, then discards its
## least useful card.
func bot_take_turn_simple() -> void:
	if game_over:
		return
	if is_human_turn():
		status_text = "Noch dein Zug — wirf zuerst eine Karte ab."
		return

	if draw_deck.is_empty():
		_refill_deck_from_discard()

	var drawn: Card = draw_deck.draw_card()
	if drawn != null:
		bot_player.add_card(drawn)

	var melds_laid := _bot_lay_melds()
	var extends_made := 0
	if bot_has_melded:
		extends_made = _bot_extend_melds()

	if _check_game_over():
		return

	if not bot_player.hand.is_empty():
		var discard_index := _bot_choose_discard_index()
		var discarded: Card = bot_player.remove_card_at(discard_index)
		discard_pile.append(discarded)

		if _check_game_over():
			return

		status_text = _build_bot_turn_summary(melds_laid, extends_made, discarded)
	else:
		status_text = "Bot hat keine Karten mehr. Dein Zug."

	current_player_index = HUMAN_INDEX
	human_has_drawn = false

func _build_bot_turn_summary(melds_laid: int, extends_made: int, discarded: Card) -> String:
	var summary := "Bot hat gezogen"
	if melds_laid > 0:
		summary += ", %d Meldung(en) gelegt" % melds_laid
	if extends_made > 0:
		summary += ", %d Karte(n) angelegt" % extends_made
	summary += " und %s abgeworfen. Dein Zug — zieh eine Karte." % discarded.to_display_string()
	return summary

## Repeatedly finds and lays valid melds (Satz/Sequenz) from the bot's hand.
## Until the bot has made its own first meld, only candidates worth
## ≥ FIRST_MELD_MIN_POINTS are laid (mirrors human_lay_meld's rule). Returns
## the number of melds laid.
func _bot_lay_melds() -> int:
	var melds_laid := 0
	var found_meld := true
	while found_meld:
		found_meld = false

		var candidates := _find_meld_candidates(bot_player.hand)
		candidates.sort_custom(func(a, b): return _candidate_score(a) > _candidate_score(b))

		for indices in candidates:
			var cards: Array = []
			for i in indices:
				cards.append(bot_player.hand[i])
			var score := RummyRules.meld_score(cards)
			if not bot_has_melded and score < FIRST_MELD_MIN_POINTS:
				continue

			_remove_cards_by_indices(bot_player, indices)
			table_melds.append({"owner": BOT_INDEX, "cards": cards})
			bot_has_melded = true
			melds_laid += 1
			found_meld = true
			break

	return melds_laid

func _candidate_score(indices: Array) -> int:
	var total := 0
	for i in indices:
		total += bot_player.hand[i].get_point_value()
	return total

## Finds all valid group/run melds within hand, returned as arrays of hand
## indices (3+ indices each). Candidates may overlap; _bot_lay_melds picks
## the highest-scoring one and re-searches afterwards.
func _find_meld_candidates(hand: Array) -> Array:
	var candidates: Array = []

	# Groups: same rank, distinct suits.
	var by_rank: Dictionary = {}
	for i in range(hand.size()):
		var rank: int = hand[i].rank
		if not by_rank.has(rank):
			by_rank[rank] = []
		by_rank[rank].append(i)

	for rank in by_rank.keys():
		var seen_suits: Array = []
		var group_indices: Array = []
		for i in by_rank[rank]:
			var suit: int = hand[i].suit
			if not seen_suits.has(suit):
				seen_suits.append(suit)
				group_indices.append(i)
		if group_indices.size() >= 3:
			candidates.append(group_indices)

	# Runs: same suit, consecutive ranks (duplicate ranks within a run are skipped).
	var by_suit: Dictionary = {}
	for i in range(hand.size()):
		var suit: int = hand[i].suit
		if not by_suit.has(suit):
			by_suit[suit] = []
		by_suit[suit].append(i)

	for suit in by_suit.keys():
		var indices: Array = by_suit[suit]
		indices.sort_custom(func(a, b): return hand[a].rank < hand[b].rank)
		var run: Array = []
		for i in indices:
			if run.is_empty():
				run.append(i)
			elif hand[i].rank == hand[run[-1]].rank + 1:
				run.append(i)
			elif hand[i].rank == hand[run[-1]].rank:
				continue
			else:
				if run.size() >= 3:
					candidates.append(run.duplicate())
				run = [i]
		if run.size() >= 3:
			candidates.append(run.duplicate())

	return candidates

## Greedily extends existing table melds (own or human's) with leftover cards
## from the bot's hand, one card at a time. Returns the number of cards used.
func _bot_extend_melds() -> int:
	var extends_made := 0
	var changed := true
	while changed:
		changed = false
		for hand_index in range(bot_player.hand.size()):
			var card: Card = bot_player.hand[hand_index]
			for meld_entry in table_melds:
				var existing: Array = meld_entry["cards"]
				var combined: Array = existing.duplicate()
				combined.append(card)
				if RummyRules.is_valid_group(combined) or RummyRules.is_valid_run(combined):
					meld_entry["cards"] = combined
					bot_player.remove_card_at(hand_index)
					extends_made += 1
					changed = true
					break
			if changed:
				break
	return extends_made

## Picks the hand index of the bot's least useful card to discard: prefers
## cards with no rank-mates and no nearby same-suit cards (no meld
## potential), breaking ties by discarding the highest point value first.
func _bot_choose_discard_index() -> int:
	var hand := bot_player.hand
	var best_index := 0
	var best_score := 0
	for i in range(hand.size()):
		var usefulness := _card_usefulness(hand, i)
		var score := usefulness * 100 - hand[i].get_point_value()
		if i == 0 or score < best_score:
			best_score = score
			best_index = i
	return best_index

## Counts how many other cards in hand could combine with hand[index] into a
## meld: same rank (group potential), or same suit within 2 ranks (run potential).
func _card_usefulness(hand: Array, index: int) -> int:
	var card: Card = hand[index]
	var usefulness := 0
	for i in range(hand.size()):
		if i == index:
			continue
		var other: Card = hand[i]
		if other.rank == card.rank:
			usefulness += 1
		elif other.suit == card.suit and abs(other.rank - card.rank) <= 2:
			usefulness += 1
	return usefulness

# ── Internal helpers ──────────────────────────────────────────────────────────

func _assert_human_action_allowed() -> bool:
	if game_over:
		return false
	if not is_human_turn():
		status_text = "Noch nicht dein Zug."
		return false
	return true

func _assert_human_drew() -> bool:
	if not _assert_human_action_allowed():
		return false
	if not human_has_drawn:
		status_text = "Du musst zuerst eine Karte ziehen."
		return false
	return true

## Removes cards at the given hand indices in reverse order so earlier indices
## stay valid during successive removals.
func _remove_cards_by_indices(player: Player, indices: Array) -> void:
	var sorted: Array = indices.duplicate()
	sorted.sort()
	sorted.reverse()
	for i in sorted:
		player.remove_card_at(i)

## If the draw deck is empty, reshuffles the discard pile (keeping the top card)
## into a new draw deck.
func _refill_deck_from_discard() -> void:
	if discard_pile.size() <= 1:
		return
	var top_card: Card = discard_pile.pop_back()
	var new_deck := Deck.new()
	for card in discard_pile:
		new_deck.cards.append(card)
	new_deck.shuffle_deck()
	draw_deck = new_deck
	discard_pile.clear()
	discard_pile.append(top_card)

func _check_game_over() -> bool:
	if human_player.hand.is_empty():
		var bot_pts := RummyRules.calculate_hand_points(bot_player.hand)
		status_text = "Du hast gewonnen! (Rommé) — Bot: %d Strafpunkte." % bot_pts
		game_over = true
		winner_index = HUMAN_INDEX
		return true
	if bot_player.hand.is_empty():
		var human_pts := RummyRules.calculate_hand_points(human_player.hand)
		status_text = "Bot hat gewonnen! — Du: %d Strafpunkte." % human_pts
		game_over = true
		winner_index = BOT_INDEX
		return true
	return false

# ── Serialisation ─────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	var discard_data: Array = []
	for card in discard_pile:
		discard_data.append(card.to_dict())

	var melds_data: Array = []
	for meld_entry in table_melds:
		var cards_data: Array = []
		for card in meld_entry["cards"]:
			cards_data.append(card.to_dict())
		melds_data.append({"owner": meld_entry["owner"], "cards": cards_data})

	return {
		"human_player": human_player.to_dict(),
		"bot_player": bot_player.to_dict(),
		"draw_deck": draw_deck.to_array(),
		"discard_pile": discard_data,
		"table_melds": melds_data,
		"current_player_index": current_player_index,
		"human_has_drawn": human_has_drawn,
		"human_has_melded": human_has_melded,
		"bot_has_melded": bot_has_melded,
		"game_over": game_over,
		"winner_index": winner_index,
		"status_text": status_text,
	}

func from_dict(data: Dictionary) -> void:
	human_player = Player.from_dict(data.get("human_player", {}))
	bot_player = Player.from_dict(data.get("bot_player", {}))
	draw_deck = Deck.from_array(data.get("draw_deck", []))
	discard_pile.clear()
	for entry in data.get("discard_pile", []):
		discard_pile.append(Card.from_dict(entry))
	table_melds.clear()
	for meld_data in data.get("table_melds", []):
		var meld: Array = []
		for card_data in meld_data.get("cards", []):
			meld.append(Card.from_dict(card_data))
		table_melds.append({"owner": meld_data.get("owner", HUMAN_INDEX), "cards": meld})
	current_player_index = data.get("current_player_index", HUMAN_INDEX)
	human_has_drawn = data.get("human_has_drawn", false)
	human_has_melded = data.get("human_has_melded", false)
	bot_has_melded = data.get("bot_has_melded", false)
	game_over = data.get("game_over", false)
	winner_index = data.get("winner_index", -1)
	status_text = data.get("status_text", "")
