class_name Player
extends RefCounted

## A player and their hand of cards. Pure data + logic — no Godot UI dependencies.

var player_name: String
var hand: Array[Card] = []

func _init(p_name: String = "Player") -> void:
	player_name = p_name

func add_card(card: Card) -> void:
	if card != null:
		hand.append(card)

## Removes and returns the card at hand_index, or null if the index is out of range.
func remove_card_at(hand_index: int) -> Card:
	if hand_index < 0 or hand_index >= hand.size():
		return null
	return hand.pop_at(hand_index)

## Sorts the hand by suit first, then by rank within each suit. Jokers always
## sort to the end.
func sort_hand() -> void:
	hand.sort_custom(_compare_cards)

func _compare_cards(a: Card, b: Card) -> bool:
	if a.is_joker != b.is_joker:
		return not a.is_joker
	if a.is_joker:
		return false
	if a.suit != b.suit:
		return a.suit < b.suit
	return a.rank < b.rank

func to_dict() -> Dictionary:
	var hand_data: Array = []
	for card in hand:
		hand_data.append(card.to_dict())
	return {
		"name": player_name,
		"hand": hand_data,
	}

static func from_dict(data: Dictionary) -> Player:
	var player := Player.new(data.get("name", "Player"))
	for entry in data.get("hand", []):
		player.hand.append(Card.from_dict(entry))
	return player
