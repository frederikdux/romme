class_name GameState
extends RefCounted

## Owns and mutates all game data for a single match. No Godot UI dependencies —
## UI scripts should call these methods and then re-render from the results.
##
## players[0] is the human ("Du"); players[1..num_opponents] are bots
## ("Gegner 1".."Gegner N"). Turn order cycles through `players` in index
## order, wrapping back to the human (enforced via human_has_drawn flag):
##   1. DRAW    — human_draw_from_deck / human_draw_from_discard
##   2. OPTIONAL — human_lay_meld / human_extend_meld (any number of times)
##   3. DISCARD — human_discard_card  →  advances to the next player
##
## Bot turns are driven step-by-step by the UI via bot_draw_step() /
## bot_meld_step() / bot_extend_step() / bot_discard_step(), so the UI can
## pace and animate each step individually.
##
## table_melds entries: {"owner": int, "cards": Array[Card]}

const STARTING_HAND_SIZE := 13
const FIRST_MELD_MIN_POINTS := 40

const HUMAN_INDEX := 0
const MIN_OPPONENTS := 1
const MAX_OPPONENTS := 4

## Increased from the standard 2 for easier manual testing of joker behavior.
const DEFAULT_JOKER_COUNT := 6
const MAX_JOKER_COUNT := 8

## players[0] is the human, players[1..num_opponents] are bots.
var players: Array[Player] = []
var num_opponents: int = 1

## Number of jokers added to the deck for new_game(). Configurable via the
## options overlay before starting the next round.
var joker_count: int = DEFAULT_JOKER_COUNT

var draw_deck: Deck
var discard_pile: Array[Card] = []
## Each element is a Dictionary: {"owner": player_index, "cards": Array}.
var table_melds: Array = []
var current_player_index: int = HUMAN_INDEX

## Per-turn phase flag; reset to false at the start of each human turn.
var human_has_drawn: bool = false
## Set permanently once the human lays their first valid meld (≥40 pts).
var human_has_melded: bool = false
## bot_has_melded[i] tracks players[i + 1]. Sized to num_opponents.
var bot_has_melded: Array[bool] = []

var game_over: bool = false
var winner_index: int = -1
var status_text: String = ""

## Incremented by new_game(); the very first game played is round 1.
var round_number: int = 0

func _init() -> void:
	players = [Player.new("Du")]
	draw_deck = Deck.new()

## Resets all state and deals a fresh game with the given number of bot opponents.
func new_game(p_num_opponents: int = num_opponents) -> void:
	num_opponents = clampi(p_num_opponents, MIN_OPPONENTS, MAX_OPPONENTS)

	players = [Player.new("Du")]
	for i in range(1, num_opponents + 1):
		players.append(Player.new("Gegner %d" % i))

	draw_deck = Deck.new()
	draw_deck.build_standard_deck(joker_count)
	draw_deck.shuffle_deck()
	discard_pile.clear()
	table_melds.clear()
	human_has_drawn = false
	human_has_melded = false
	bot_has_melded.clear()
	for _i in range(num_opponents):
		bot_has_melded.append(false)
	game_over = false
	winner_index = -1

	for _round in range(STARTING_HAND_SIZE):
		for player in players:
			player.add_card(draw_deck.draw_card())
	players[HUMAN_INDEX].sort_hand()

	var starting_card := draw_deck.draw_card()
	if starting_card != null:
		discard_pile.append(starting_card)

	current_player_index = HUMAN_INDEX
	status_text = "Dein Zug — ziehe eine Karte vom Deck oder Ablagestapel."
	round_number += 1

func get_human_hand() -> Array[Card]:
	return players[HUMAN_INDEX].hand

## Penalty points the human would incur if the round ended right now
## (sum of unmelded card values still in hand).
func get_human_penalty_points() -> int:
	return RummyRules.calculate_hand_points(players[HUMAN_INDEX].hand)

## Penalty points the bot at 1-based index (1..num_opponents) would incur if
## the round ended right now.
func get_bot_penalty_points(bot_number: int = 1) -> int:
	if bot_number < 1 or bot_number > num_opponents:
		return 0
	return RummyRules.calculate_hand_points(players[bot_number].hand)

func get_player_hand_count(player_index: int) -> int:
	if player_index < 0 or player_index >= players.size():
		return 0
	return players[player_index].hand.size()

func get_player_name(player_index: int) -> String:
	if player_index < 0 or player_index >= players.size():
		return ""
	return players[player_index].player_name

func get_top_discard_card() -> Card:
	if discard_pile.is_empty():
		return null
	return discard_pile.back()

func get_status_text() -> String:
	return status_text

func is_human_turn() -> bool:
	return current_player_index == HUMAN_INDEX

func get_current_player_index() -> int:
	return current_player_index

func is_bot_turn(bot_number: int) -> bool:
	return current_player_index == bot_number

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
	players[HUMAN_INDEX].add_card(card)
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
	players[HUMAN_INDEX].add_card(card)
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

	var human_hand := players[HUMAN_INDEX].hand
	var selected: Array[Card] = []
	for i in indices:
		if i < 0 or i >= human_hand.size():
			status_text = "Ungültige Kartenauswahl."
			return false
		selected.append(human_hand[i])

	if not (RummyRules.is_valid_group(selected) or RummyRules.is_valid_run(selected)):
		status_text = "Keine gültige Meldung!"
		return false

	if not human_has_melded:
		var score := RummyRules.meld_score(selected)
		if score < FIRST_MELD_MIN_POINTS:
			status_text = "Erstmeldung braucht mindestens %d Punkte — diese hat %d." % [FIRST_MELD_MIN_POINTS, score]
			return false

	_remove_cards_by_indices(players[HUMAN_INDEX], indices)
	table_melds.append({"owner": HUMAN_INDEX, "cards": RummyRules.order_meld_cards(selected)})
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

	var human_hand := players[HUMAN_INDEX].hand
	var new_cards: Array[Card] = []
	for i in card_indices:
		if i < 0 or i >= human_hand.size():
			status_text = "Ungültige Kartenauswahl."
			return false
		new_cards.append(human_hand[i])

	# Use untyped array so dict-sourced Card values don't need explicit casting.
	var combined: Array = []
	for c in existing:
		combined.append(c)
	for c in new_cards:
		combined.append(c)

	if not (RummyRules.is_valid_group(combined) or RummyRules.is_valid_run(combined)):
		status_text = "Karte(n) passen nicht an diese Meldung."
		return false

	_remove_cards_by_indices(players[HUMAN_INDEX], card_indices)
	meld_entry["cards"] = RummyRules.order_meld_cards(combined)

	if _check_game_over():
		return true
	status_text = "Erfolgreich angelegt!"
	return true

## Exchanges the joker in the table meld at meld_index for the matching real
## card from the human's hand: the real card takes the joker's place on the
## table, and the joker moves to the human's hand — usable freely afterwards,
## as if drawn from the deck. Requires the human's first meld to be laid.
func human_swap_joker(meld_index: int, hand_index: int) -> bool:
	if not _assert_human_action_allowed():
		return false
	if not human_has_melded:
		status_text = "Joker-Tausch erst nach deiner Erstmeldung möglich."
		return false
	if meld_index < 0 or meld_index >= table_melds.size():
		status_text = "Ungültige Meldung."
		return false

	var human_hand := players[HUMAN_INDEX].hand
	if hand_index < 0 or hand_index >= human_hand.size():
		status_text = "Ungültige Kartenauswahl."
		return false

	var meld_entry: Dictionary = table_melds[meld_index]
	var cards: Array = meld_entry["cards"]
	var hand_card: Card = human_hand[hand_index]

	if not RummyRules.is_joker_swap_match(cards, hand_card):
		status_text = "Diese Karte passt nicht auf den Joker."
		return false

	var joker_index := -1
	for i in range(cards.size()):
		if cards[i].is_joker:
			joker_index = i
			break
	if joker_index == -1:
		status_text = "Kein Joker in dieser Meldung."
		return false

	var joker: Card = cards[joker_index]
	cards[joker_index] = hand_card
	players[HUMAN_INDEX].remove_card_at(hand_index)
	players[HUMAN_INDEX].add_card(joker)
	players[HUMAN_INDEX].sort_hand()
	meld_entry["cards"] = RummyRules.order_meld_cards(cards)

	status_text = "Du hast den Joker gegen %s getauscht." % hand_card.to_display_string()
	return true

# ── Discard ───────────────────────────────────────────────────────────────────

## Discards the card at hand_index, ending the human's turn. Returns true on success.
func human_discard_card(hand_index: int) -> bool:
	if not _assert_human_drew():
		return false

	var card := players[HUMAN_INDEX].remove_card_at(hand_index)
	if card == null:
		status_text = "Ungültige Karte."
		return false

	discard_pile.append(card)

	if _check_game_over():
		return true

	_advance_turn()
	status_text = "Du hast %s abgeworfen. %s ist dran." % [card.to_display_string(), players[current_player_index].player_name]
	return true

func human_sort_hand() -> void:
	players[HUMAN_INDEX].sort_hand()

## Moves the card at from_index to to_index within the human's hand (used by
## drag-and-drop reordering in the UI). No turn/phase checks — purely
## cosmetic reordering, allowed any time.
func human_reorder_hand(from_index: int, to_index: int) -> void:
	var hand := players[HUMAN_INDEX].hand
	if from_index < 0 or from_index >= hand.size():
		return
	to_index = clampi(to_index, 0, hand.size() - 1)
	if from_index == to_index:
		return
	var card: Card = hand.pop_at(from_index)
	hand.insert(to_index, card)

# ── Turn advancement ──────────────────────────────────────────────────────────

## Advances to the next player (0 -> 1 -> ... -> num_opponents -> 0),
## resetting human_has_drawn whenever play returns to the human.
func _advance_turn() -> void:
	current_player_index = (current_player_index + 1) % players.size()
	if current_player_index == HUMAN_INDEX:
		human_has_drawn = false

# ── Bot ───────────────────────────────────────────────────────────────────────

## Draws one card for the current bot. Returns {"card": Card or null}.
func bot_draw_step() -> Dictionary:
	if draw_deck.is_empty():
		_refill_deck_from_discard()
	var drawn: Card = draw_deck.draw_card()
	if drawn != null:
		players[current_player_index].add_card(drawn)
	return {"card": drawn}

## Lays at most ONE valid meld for the current bot (call repeatedly until
## "laid" is false). Respects the same "first meld ≥ FIRST_MELD_MIN_POINTS"
## rule as the human.
func bot_meld_step() -> Dictionary:
	var bot_idx := current_player_index
	var hand := players[bot_idx].hand
	var has_melded: bool = bot_has_melded[bot_idx - 1]

	var candidates := _find_meld_candidates(hand)
	candidates.sort_custom(func(a, b): return _candidate_score(hand, a) > _candidate_score(hand, b))

	for indices in candidates:
		var cards: Array = []
		for i in indices:
			cards.append(hand[i])
		var score := RummyRules.meld_score(cards)
		if not has_melded and score < FIRST_MELD_MIN_POINTS:
			continue

		_remove_cards_by_indices(players[bot_idx], indices)
		table_melds.append({"owner": bot_idx, "cards": RummyRules.order_meld_cards(cards)})
		bot_has_melded[bot_idx - 1] = true
		return {"laid": true}

	return {"laid": false}

## Extends ONE table meld with ONE card from the current bot's hand (call
## repeatedly until "extended" is false). No-op if the bot hasn't melded yet.
func bot_extend_step() -> Dictionary:
	var bot_idx := current_player_index
	if not bot_has_melded[bot_idx - 1]:
		return {"extended": false}

	var hand := players[bot_idx].hand
	for hand_index in range(hand.size()):
		var card: Card = hand[hand_index]
		for meld_entry in table_melds:
			var existing: Array = meld_entry["cards"]
			var combined: Array = existing.duplicate()
			combined.append(card)
			if RummyRules.is_valid_group(combined) or RummyRules.is_valid_run(combined):
				meld_entry["cards"] = RummyRules.order_meld_cards(combined)
				players[bot_idx].remove_card_at(hand_index)
				return {"extended": true, "card": card}

	return {"extended": false}

## Discards the current bot's least useful card, checks for game over, and
## advances to the next player. Sets status_text for the resulting state.
func bot_discard_step() -> Dictionary:
	var bot_idx := current_player_index
	var hand := players[bot_idx].hand
	if hand.is_empty():
		_advance_turn()
		return {"discarded": null, "game_over": false}

	var discard_index := _bot_choose_discard_index(bot_idx)
	var discarded: Card = players[bot_idx].remove_card_at(discard_index)
	discard_pile.append(discarded)

	if _check_game_over():
		return {"discarded": discarded, "game_over": true}

	_advance_turn()
	if current_player_index == HUMAN_INDEX:
		status_text = "%s hat %s abgeworfen. Dein Zug — zieh eine Karte." % [players[bot_idx].player_name, discarded.to_display_string()]
	else:
		status_text = "%s denkt..." % players[current_player_index].player_name
	return {"discarded": discarded, "game_over": false}

func _candidate_score(hand: Array, indices: Array) -> int:
	var total := 0
	for i in indices:
		total += hand[i].get_point_value()
	return total

## Finds all valid group/run melds within hand, returned as arrays of hand
## indices (3+ indices each). Candidates may overlap; the caller picks
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

## Picks the hand index of player_index's least useful card to discard:
## prefers cards with no rank-mates and no nearby same-suit cards (no meld
## potential), breaking ties by discarding the highest point value first.
func _bot_choose_discard_index(player_index: int) -> int:
	var hand := players[player_index].hand
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
	for i in range(players.size()):
		if players[i].hand.is_empty():
			game_over = true
			winner_index = i
			status_text = _build_game_over_text(i)
			return true
	return false

func _build_game_over_text(winner: int) -> String:
	var header: String
	if winner == HUMAN_INDEX:
		header = "Du hast gewonnen! (Rommé)"
	else:
		header = "%s hat gewonnen! (Rommé)" % players[winner].player_name

	var penalty_parts: Array[String] = []
	for i in range(players.size()):
		if i == winner:
			continue
		var pts := RummyRules.calculate_hand_points(players[i].hand)
		var name := "Du" if i == HUMAN_INDEX else players[i].player_name
		penalty_parts.append("%s: %d" % [name, pts])

	return "%s — Strafpunkte: %s." % [header, ", ".join(penalty_parts)]

# ── Serialisation ─────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	var players_data: Array = []
	for player in players:
		players_data.append(player.to_dict())

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
		"players": players_data,
		"num_opponents": num_opponents,
		"draw_deck": draw_deck.to_array(),
		"discard_pile": discard_data,
		"table_melds": melds_data,
		"current_player_index": current_player_index,
		"human_has_drawn": human_has_drawn,
		"human_has_melded": human_has_melded,
		"bot_has_melded": bot_has_melded.duplicate(),
		"game_over": game_over,
		"winner_index": winner_index,
		"status_text": status_text,
		"round_number": round_number,
		"joker_count": joker_count,
	}

func from_dict(data: Dictionary) -> void:
	players.clear()
	for entry in data.get("players", []):
		players.append(Player.from_dict(entry))
	if players.is_empty():
		players.append(Player.new("Du"))

	num_opponents = data.get("num_opponents", players.size() - 1)

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
	bot_has_melded.clear()
	var saved: Array = data.get("bot_has_melded", [])
	for i in range(num_opponents):
		bot_has_melded.append(saved[i] if i < saved.size() else false)

	game_over = data.get("game_over", false)
	winner_index = data.get("winner_index", -1)
	status_text = data.get("status_text", "")
	round_number = data.get("round_number", round_number)
	joker_count = data.get("joker_count", joker_count)
