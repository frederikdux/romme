class_name RummyRules
extends RefCounted

## Static helpers for Rommé meld validation and scoring.
##
## Group (Satz):    3–4 cards, same rank, all different suits.
## Run (Sequenz):   3+ consecutive cards, same suit, ace low or high.
## Jokers:          A meld may contain multiple jokers as long as there are
##                  more normal cards than jokers, and (for runs) no two
##                  jokers end up adjacent to each other in the sequence —
##                  each joker fills a single-card internal gap or extends one
##                  end of the run by at most one card. There is no overall
##                  size cap beyond what these rules imply.
##
## All functions accept untyped Array so they work with both Array[Card] and
## Dictionary-sourced arrays without runtime cast errors.

## Splits cards into joker count and the list of non-joker cards.
static func _split_jokers(cards: Array) -> Dictionary:
	var jokers := 0
	var non_jokers: Array = []
	for card in cards:
		if card.is_joker:
			jokers += 1
		else:
			non_jokers.append(card)
	return {"jokers": jokers, "non_jokers": non_jokers}

## True if cards form a valid group: 3–4 cards, same rank, all different
## suits, with more non-joker cards than jokers (so at most one joker, since
## a group can have at most 4 cards / suits).
static func is_valid_group(cards: Array) -> bool:
	if cards.size() < 3 or cards.size() > 4:
		return false

	var split := _split_jokers(cards)
	var jokers: int = split["jokers"]
	var non_jokers: Array = split["non_jokers"]

	if non_jokers.is_empty() or non_jokers.size() <= jokers:
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

## Computes how `jokers` wildcards would fill the run formed by `non_jokers`
## under the given ace interpretation. Returns {"valid": false} if the
## non-joker ranks can't form part of a consecutive run this way — i.e. there's
## an internal gap wider than one card, or more than two "extension" slots
## would be needed at the ends (which would force two jokers to sit next to
## each other). On success, returns "ranks" (sorted non-joker run-ranks),
## "internal_gaps" (run-ranks of single-card gaps between non-jokers), and
## "low_ext"/"high_ext" (whether a joker extends the run below/above the
## non-jokers' own span).
static func _run_layout(non_jokers: Array, jokers: int, ace_high: bool) -> Dictionary:
	var ranks: Array[int] = []
	for card in non_jokers:
		ranks.append(_run_rank(card, ace_high))
	ranks.sort()

	var internal_gaps: Array[int] = []
	for k in range(ranks.size() - 1):
		var diff: int = ranks[k + 1] - ranks[k]
		if diff <= 0 or diff >= 3:
			return {"valid": false}
		if diff == 2:
			internal_gaps.append(ranks[k] + 1)

	var extension_needed: int = jokers - internal_gaps.size()
	if extension_needed < 0 or extension_needed > 2:
		return {"valid": false}

	var range_min: int = 2 if ace_high else 1
	var range_max: int = 14 if ace_high else 13
	var min_rank: int = ranks[0]
	var max_rank: int = ranks[ranks.size() - 1]
	var low_ext := false
	var high_ext := false

	if extension_needed == 1:
		if min_rank - 1 >= range_min:
			low_ext = true
		elif max_rank + 1 <= range_max:
			high_ext = true
		else:
			return {"valid": false}
	elif extension_needed == 2:
		if min_rank - 1 >= range_min and max_rank + 1 <= range_max:
			low_ext = true
			high_ext = true
		else:
			return {"valid": false}

	return {
		"valid": true,
		"ranks": ranks,
		"internal_gaps": internal_gaps,
		"low_ext": low_ext,
		"high_ext": high_ext,
	}

## Resolves the run layout for non_jokers + jokers, trying ace-low before
## ace-high. Returns {"valid": false} if neither interpretation works;
## otherwise the winning _run_layout() result with an added "ace_high" key.
static func _resolve_run_layout(non_jokers: Array, jokers: int) -> Dictionary:
	for ace_high in [false, true]:
		var layout := _run_layout(non_jokers, jokers, ace_high)
		if layout.get("valid", false):
			layout["ace_high"] = ace_high
			return layout
	return {"valid": false}

## True if cards form a valid run: same suit, ≥3 consecutive ranks (ace low
## before 2, or ace high after king), with more non-joker cards than jokers
## and no internal gap or end-extension that would force two jokers to be
## adjacent. Card order in the input array does not matter.
static func is_valid_run(cards: Array) -> bool:
	if cards.size() < 3:
		return false

	var split := _split_jokers(cards)
	var jokers: int = split["jokers"]
	var non_jokers: Array = split["non_jokers"]

	if non_jokers.is_empty() or non_jokers.size() <= jokers:
		return false

	var shared_suit: int = non_jokers[0].suit
	for card in non_jokers:
		if card.suit != shared_suit:
			return false

	return _resolve_run_layout(non_jokers, jokers).get("valid", false)

## Returns an array the same size as cards: for each joker, the Card it
## represents (suit + rank); null for non-joker cards, or for jokers in a
## meld that isn't a valid group/run. Used so jokers count as their
## substitute for first-meld scoring, and to show "= 6♥" on the table.
static func get_joker_substitutes(cards: Array) -> Array:
	var result: Array = []
	for _i in range(cards.size()):
		result.append(null)

	var split := _split_jokers(cards)
	var jokers: int = split["jokers"]
	var non_jokers: Array = split["non_jokers"]

	if jokers == 0 or non_jokers.is_empty():
		return result

	if is_valid_group(cards):
		var shared_rank: int = non_jokers[0].rank
		var used_suits: Array = []
		for card in non_jokers:
			used_suits.append(card.suit)
		var missing_suits: Array = []
		for suit in [Card.Suit.HEARTS, Card.Suit.DIAMONDS, Card.Suit.CLUBS, Card.Suit.SPADES]:
			if not used_suits.has(suit):
				missing_suits.append(suit)

		var mi := 0
		for i in range(cards.size()):
			if cards[i].is_joker and mi < missing_suits.size():
				result[i] = Card.new(missing_suits[mi], shared_rank)
				mi += 1
		return result

	if is_valid_run(cards):
		var shared_suit: int = non_jokers[0].suit
		var layout := _resolve_run_layout(non_jokers, jokers)
		var ranks: Array = layout["ranks"]

		var target_ranks: Array[int] = []
		for r in layout["internal_gaps"]:
			target_ranks.append(r)
		if layout["low_ext"]:
			target_ranks.append(ranks[0] - 1)
		if layout["high_ext"]:
			target_ranks.append(ranks[ranks.size() - 1] + 1)
		target_ranks.sort()

		var ti := 0
		for i in range(cards.size()):
			if cards[i].is_joker and ti < target_ranks.size():
				result[i] = _run_rank_to_card(shared_suit, target_ranks[ti])
				ti += 1
		return result

	return result

## True if hand_card is the real card a joker within meld_cards represents —
## i.e. hand_card could be swapped onto the table for that joker (same suit
## and rank as one of get_joker_substitutes(meld_cards)). False if meld_cards
## has no matching joker, hand_card is itself a joker, or hand_card is null.
static func is_joker_swap_match(meld_cards: Array, hand_card: Card) -> bool:
	if hand_card == null or hand_card.is_joker:
		return false
	for substitute in get_joker_substitutes(meld_cards):
		if substitute != null and substitute.suit == hand_card.suit and substitute.rank == hand_card.rank:
			return true
	return false

## Returns a copy of cards reordered for table display: groups sorted by
## suit, runs sorted by rank (ace placed low or high to match the run), with
## each joker positioned where the card it substitutes would go. Returns
## cards unchanged if it isn't a valid group/run.
static func order_meld_cards(cards: Array) -> Array:
	var substitutes := get_joker_substitutes(cards)

	if is_valid_group(cards):
		var pairs: Array = []
		for i in range(cards.size()):
			pairs.append([cards[i], substitutes[i]])
		pairs.sort_custom(func(a, b):
			var a_suit: int = a[1].suit if a[1] != null else a[0].suit
			var b_suit: int = b[1].suit if b[1] != null else b[0].suit
			return a_suit < b_suit)
		var ordered: Array = []
		for p in pairs:
			ordered.append(p[0])
		return ordered

	if is_valid_run(cards):
		var split := _split_jokers(cards)
		var ace_high: bool = _resolve_run_layout(split["non_jokers"], split["jokers"])["ace_high"]

		var pairs: Array = []
		for i in range(cards.size()):
			pairs.append([cards[i], substitutes[i]])
		pairs.sort_custom(func(a, b):
			var a_card: Card = a[1] if a[1] != null else a[0]
			var b_card: Card = b[1] if b[1] != null else b[0]
			return _run_rank(a_card, ace_high) < _run_rank(b_card, ace_high))
		var ordered: Array = []
		for p in pairs:
			ordered.append(p[0])
		return ordered

	return cards.duplicate()

## Sum of point values for a set of cards. Each joker counts as the card it
## substitutes (see get_joker_substitutes), not its own 20-point value.
static func meld_score(cards: Array) -> int:
	var substitutes := get_joker_substitutes(cards)
	var total := 0
	for i in range(cards.size()):
		if cards[i].is_joker and substitutes[i] != null:
			total += substitutes[i].get_point_value()
		else:
			total += cards[i].get_point_value()
	return total

## Sum of point values for a player's entire hand (used for penalty scoring).
static func calculate_hand_points(hand: Array) -> int:
	var total := 0
	for card in hand:
		total += card.get_point_value()
	return total
