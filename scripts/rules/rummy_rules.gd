class_name RummyRules
extends RefCounted

## Static helpers for Rommé meld validation and scoring.
##
## Group (Satz):    3–4 cards, same rank, all different suits, max 1 joker.
## Run (Sequenz):   3+ consecutive cards, same suit, ace low only, max 1 joker.
## Joker:           Substitutes exactly one missing card per meld.
##
## All functions accept untyped Array so they work with both Array[Card] and
## Dictionary-sourced arrays without runtime cast errors.

## True if cards form a valid group: same rank, 3–4 cards, all different suits, ≤1 joker.
static func is_valid_group(cards: Array) -> bool:
	if cards.size() < 3 or cards.size() > 4:
		return false

	var jokers := 0
	var non_jokers: Array = []
	for card in cards:
		if card.is_joker:
			jokers += 1
		else:
			non_jokers.append(card)

	if jokers > 1:
		return false
	if non_jokers.is_empty():
		return false

	var shared_rank: int = non_jokers[0].rank
	var seen_suits: Array = []
	for card in non_jokers:
		if card.rank != shared_rank:
			return false
		if seen_suits.has(card.suit):
			return false
		seen_suits.append(card.suit)

	return true

## Maps a card's rank to its position within a run: aces are 1 (low) or 14
## (high, after King) depending on ace_high; all other ranks pass through.
static func _run_rank(card: Card, ace_high: bool) -> int:
	if card.rank == 1 and ace_high:
		return 14
	return card.rank

## Converts a run-position back to a Card (run rank 14 = Ace, displayed high).
static func _run_rank_to_card(suit: int, run_rank: int) -> Card:
	if run_rank == 14:
		return Card.new(suit, 1)
	return Card.new(suit, run_rank)

## True if the given non-joker run cards (with `jokers` extra wildcard slots)
## form a consecutive sequence under the given ace interpretation.
static func _is_consecutive_run(non_jokers: Array, jokers: int, ace_high: bool) -> bool:
	var ranks: Array[int] = []
	for card in non_jokers:
		ranks.append(_run_rank(card, ace_high))
	ranks.sort()

	# No duplicate ranks.
	for k in range(ranks.size() - 1):
		if ranks[k] == ranks[k + 1]:
			return false

	var span: int = ranks[ranks.size() - 1] - ranks[0] + 1
	return span <= ranks.size() + jokers

## True if cards form a valid run: same suit, ≥3 consecutive ranks
## (ace low before 2, or ace high after king), ≤1 joker.
## Card order in the input array does not matter.
static func is_valid_run(cards: Array) -> bool:
	if cards.size() < 3:
		return false

	var jokers := 0
	var non_jokers: Array = []
	for card in cards:
		if card.is_joker:
			jokers += 1
		else:
			non_jokers.append(card)

	if jokers > 1:
		return false
	if non_jokers.is_empty():
		return false

	var shared_suit: int = non_jokers[0].suit
	for card in non_jokers:
		if card.suit != shared_suit:
			return false

	return _is_consecutive_run(non_jokers, jokers, false) or _is_consecutive_run(non_jokers, jokers, true)

## Returns the card a joker in this meld represents (suit + rank), or null if
## the meld has no joker or isn't a valid group/run. Used so the joker counts
## as its substitute for first-meld scoring, and to show "= 6♥" on the table.
static func get_joker_substitute(cards: Array) -> Card:
	var joker_found := false
	var non_jokers: Array = []
	for card in cards:
		if card.is_joker:
			joker_found = true
		else:
			non_jokers.append(card)

	if not joker_found or non_jokers.is_empty():
		return null

	if is_valid_group(cards):
		var shared_rank: int = non_jokers[0].rank
		var used_suits: Array = []
		for card in non_jokers:
			used_suits.append(card.suit)
		for suit in [Card.Suit.HEARTS, Card.Suit.DIAMONDS, Card.Suit.CLUBS, Card.Suit.SPADES]:
			if not used_suits.has(suit):
				return Card.new(suit, shared_rank)
		return null

	if is_valid_run(cards):
		var shared_suit: int = non_jokers[0].suit
		for ace_high in [false, true]:
			if not _is_consecutive_run(non_jokers, 1, ace_high):
				continue
			var ranks: Array[int] = []
			for card in non_jokers:
				ranks.append(_run_rank(card, ace_high))
			ranks.sort()
			for i in range(ranks.size() - 1):
				if ranks[i + 1] - ranks[i] > 1:
					return _run_rank_to_card(shared_suit, ranks[i] + 1)
			if ranks[0] > 1:
				return _run_rank_to_card(shared_suit, ranks[0] - 1)
			return _run_rank_to_card(shared_suit, ranks[ranks.size() - 1] + 1)
		return null

	return null

## True if hand_card is the real card a joker within meld_cards represents —
## i.e. hand_card could be swapped onto the table for that joker (same suit
## and rank as get_joker_substitute(meld_cards)). False if meld_cards has no
## joker, hand_card is itself a joker, or hand_card doesn't match.
static func is_joker_swap_match(meld_cards: Array, hand_card: Card) -> bool:
	if hand_card == null or hand_card.is_joker:
		return false
	var substitute: Card = get_joker_substitute(meld_cards)
	return substitute != null and substitute.suit == hand_card.suit and substitute.rank == hand_card.rank

## Returns a copy of cards reordered for table display: groups sorted by
## suit, runs sorted by rank (ace placed low or high to match the run), with
## a joker positioned where the card it substitutes would go. Returns cards
## unchanged if it isn't a valid group/run.
static func order_meld_cards(cards: Array) -> Array:
	var substitute: Card = get_joker_substitute(cards)

	if is_valid_group(cards):
		var ordered: Array = cards.duplicate()
		ordered.sort_custom(func(a, b):
			var a_suit: int = substitute.suit if (a.is_joker and substitute != null) else a.suit
			var b_suit: int = substitute.suit if (b.is_joker and substitute != null) else b.suit
			return a_suit < b_suit)
		return ordered

	if is_valid_run(cards):
		var non_jokers: Array = []
		var jokers := 0
		for card in cards:
			if card.is_joker:
				jokers += 1
			else:
				non_jokers.append(card)
		var ace_high := not _is_consecutive_run(non_jokers, jokers, false) and _is_consecutive_run(non_jokers, jokers, true)

		var ordered: Array = cards.duplicate()
		ordered.sort_custom(func(a, b):
			var a_card: Card = substitute if (a.is_joker and substitute != null) else a
			var b_card: Card = substitute if (b.is_joker and substitute != null) else b
			return _run_rank(a_card, ace_high) < _run_rank(b_card, ace_high))
		return ordered

	return cards.duplicate()

## Sum of point values for a set of cards. A joker counts as the card it
## substitutes (see get_joker_substitute), not its own 20-point value.
static func meld_score(cards: Array) -> int:
	var substitute: Card = get_joker_substitute(cards)
	var total := 0
	for card in cards:
		if card.is_joker and substitute != null:
			total += substitute.get_point_value()
		else:
			total += card.get_point_value()
	return total

## Sum of point values for a player's entire hand (used for penalty scoring).
static func calculate_hand_points(hand: Array) -> int:
	var total := 0
	for card in hand:
		total += card.get_point_value()
	return total
