class_name Card
extends RefCounted

## A single playing card. Pure data + helpers — no Godot UI dependencies.

enum Suit { HEARTS, DIAMONDS, CLUBS, SPADES }

const RANK_LABELS := {
	1: "A",
	11: "J",
	12: "Q",
	13: "K",
}

const SUIT_SYMBOLS := {
	Suit.HEARTS: "♥",
	Suit.DIAMONDS: "♦",
	Suit.CLUBS: "♣",
	Suit.SPADES: "♠",
}

const SUIT_NAMES := {
	Suit.HEARTS: "hearts",
	Suit.DIAMONDS: "diamonds",
	Suit.CLUBS: "clubs",
	Suit.SPADES: "spades",
}

var suit: Suit
var rank: int # 1-13, ace is 1 (low)
var is_joker: bool

func _init(p_suit: Suit = Suit.HEARTS, p_rank: int = 1, p_is_joker: bool = false) -> void:
	suit = p_suit
	rank = p_rank
	is_joker = p_is_joker

## "A", "J", "Q", "K" for special ranks, otherwise the number as text.
func get_rank_label() -> String:
	if RANK_LABELS.has(rank):
		return RANK_LABELS[rank]
	return str(rank)

func get_suit_symbol() -> String:
	return SUIT_SYMBOLS.get(suit, "?")

func to_display_string() -> String:
	if is_joker:
		return "Joker"
	return "%s%s" % [get_rank_label(), get_suit_symbol()]

## Point value for scoring: Joker=20, Ace=11, 10/J/Q/K=10, others=face value.
func get_point_value() -> int:
	if is_joker:
		return 20
	if rank == 1:
		return 11
	if rank >= 10:
		return 10
	return rank

func to_dict() -> Dictionary:
	return {
		"suit": suit,
		"rank": rank,
		"is_joker": is_joker,
	}

static func from_dict(data: Dictionary) -> Card:
	return Card.new(
		data.get("suit", Suit.HEARTS),
		data.get("rank", 1),
		data.get("is_joker", false)
	)
