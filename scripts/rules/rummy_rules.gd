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

## True if cards form a valid group: same rank, ≥3 cards, all different suits, ≤1 joker.
static func is_valid_group(cards: Array) -> bool:
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

	var shared_rank: int = non_jokers[0].rank
	var seen_suits: Array = []
	for card in non_jokers:
		if card.rank != shared_rank:
			return false
		if seen_suits.has(card.suit):
			return false
		seen_suits.append(card.suit)

	return true

## True if cards form a valid run: same suit, ≥3 consecutive ranks, ace low, ≤1 joker.
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

	non_jokers.sort_custom(func(a, b): return a.rank < b.rank)

	# No duplicate ranks among non-jokers.
	for k in range(non_jokers.size() - 1):
		if non_jokers[k].rank == non_jokers[k + 1].rank:
			return false

	var min_rank: int = non_jokers[0].rank
	var max_rank: int = non_jokers[non_jokers.size() - 1].rank
	var span := max_rank - min_rank + 1

	# Without joker: all cards must be strictly consecutive.
	# With 1 joker: at most 1 gap OR joker extends one end → span ≤ cards.size().
	return span <= cards.size()

## Sum of point values for a set of cards.
static func meld_score(cards: Array) -> int:
	var total := 0
	for card in cards:
		total += card.get_point_value()
	return total

## Sum of point values for a player's entire hand (used for penalty scoring).
static func calculate_hand_points(hand: Array) -> int:
	var total := 0
	for card in hand:
		total += card.get_point_value()
	return total
