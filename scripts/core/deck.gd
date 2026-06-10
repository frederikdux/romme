class_name Deck
extends RefCounted

## A draw pile of cards. Pure data + logic — no Godot UI dependencies.

var cards: Array[Card] = []

## Replaces the contents with two standard 52-card decks (104 cards, no jokers), unshuffled.
func build_standard_deck() -> void:
	cards.clear()
	var suits := [Card.Suit.HEARTS, Card.Suit.DIAMONDS, Card.Suit.CLUBS, Card.Suit.SPADES]
	for _i in range(2):
		for suit in suits:
			for rank in range(1, 14):
				cards.append(Card.new(suit, rank))

func shuffle_deck() -> void:
	cards.shuffle()

## Removes and returns the top card, or null if the deck is empty.
func draw_card() -> Card:
	if cards.is_empty():
		return null
	return cards.pop_back()

func is_empty() -> bool:
	return cards.is_empty()

func size() -> int:
	return cards.size()

func to_array() -> Array:
	var data: Array = []
	for card in cards:
		data.append(card.to_dict())
	return data

static func from_array(data: Array) -> Deck:
	var deck := Deck.new()
	for entry in data:
		deck.cards.append(Card.from_dict(entry))
	return deck
