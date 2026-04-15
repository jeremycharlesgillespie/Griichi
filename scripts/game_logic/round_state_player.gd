## round_state_player.gd — Individual player state within a round.
##
## Tracks hand, pond (discards), calls, riichi status, furiten, and
## validates legal actions (discard restrictions, call eligibility).
class_name RoundStatePlayer
extends RefCounted


# ── Properties ─────────────────────────────────────────────────

var index: int = 0
var wind: Tile.Wind = Tile.Wind.EAST
var is_dealer: bool = false

var hand: Array = []               # Tiles in hand (13-14)
var pond: Array = []               # Discarded tiles
var calls: Array = []              # Array of HandData.RoundStateCall

var in_riichi: bool = false
var double_riichi: bool = false
var ippatsu: bool = false
var first_turn: bool = true
var temporary_furiten: bool = false

# Discard restrictions after calls
var do_riichi_discard: bool = false  # Must discard newest tile (riichi)
var do_chii_discard: bool = false    # Can't discard kuikae tile
var do_pon_discard: bool = false     # Can't discard same type as pon
var _pon_tile_type: Tile.TileType = Tile.TileType.BLANK
var _chii_forbidden_types: Array = []


# ── Accessors ──────────────────────────────────────────────────

var newest_tile: Tile:
	get:
		if hand.size() == 0:
			return null
		return hand[hand.size() - 1]


# ── Initialization ─────────────────────────────────────────────

func _init(player_index: int, player_wind: Tile.Wind, dealer: bool) -> void:
	index = player_index
	wind = player_wind
	is_dealer = dealer


# ── Draw / Discard ─────────────────────────────────────────────

func draw(tile: Tile) -> void:
	hand.append(tile)
	if not in_riichi:
		temporary_furiten = false


func discard(tile: Tile) -> bool:
	if not can_discard(tile):
		return false

	hand.erase(tile)
	pond.append(tile)

	do_riichi_discard = false
	do_chii_discard = false
	do_pon_discard = false
	_chii_forbidden_types.clear()
	first_turn = false

	return true


func can_discard(tile: Tile) -> bool:
	if not _has_tile(tile):
		return false

	# In riichi: can only discard the newest drawn tile
	if in_riichi and not do_riichi_discard:
		if tile != newest_tile:
			return false

	# Kuikae: after chii, can't discard tiles that would form the same sequence
	if do_chii_discard:
		if tile.tile_type in _chii_forbidden_types:
			return false

	# After pon, can't discard same type
	if do_pon_discard:
		if tile.tile_type == _pon_tile_type:
			return false

	return true


func get_discard_tiles() -> Array:
	if in_riichi:
		return [newest_tile]
	var result: Array = []
	for tile: Tile in hand:
		if can_discard(tile):
			result.append(tile)
	return result


## Remove a tile from the pond (when another player calls it).
func rob_tile(tile: Tile) -> void:
	for i: int in range(pond.size() - 1, -1, -1):
		if pond[i] == tile:
			pond.remove_at(i)
			return


# ── Calls ──────────────────────────────────────────────────────

func do_pon(discarder_index: int, called_tile: Tile, tile_1: Tile, tile_2: Tile) -> void:
	hand.erase(tile_1)
	hand.erase(tile_2)

	var call_tiles: Array = [called_tile, tile_1, tile_2]
	var call: HandData.RoundStateCall = HandData.RoundStateCall.new(
		HandData.RoundStateCall.CallType.PON, call_tiles, called_tile, discarder_index
	)
	calls.append(call)

	do_pon_discard = true
	_pon_tile_type = called_tile.tile_type


func do_chii(discarder_index: int, called_tile: Tile, tile_1: Tile, tile_2: Tile) -> void:
	hand.erase(tile_1)
	hand.erase(tile_2)

	var call_tiles: Array = [called_tile, tile_1, tile_2]
	var call: HandData.RoundStateCall = HandData.RoundStateCall.new(
		HandData.RoundStateCall.CallType.CHII, call_tiles, called_tile, discarder_index
	)
	calls.append(call)

	# Kuikae restriction: figure out what can't be discarded
	do_chii_discard = true
	_chii_forbidden_types = _get_kuikae_types(called_tile, tile_1, tile_2)


func do_open_kan(discarder_index: int, called_tile: Tile, t1: Tile, t2: Tile, t3: Tile) -> void:
	hand.erase(t1)
	hand.erase(t2)
	hand.erase(t3)

	var call_tiles: Array = [called_tile, t1, t2, t3]
	var call: HandData.RoundStateCall = HandData.RoundStateCall.new(
		HandData.RoundStateCall.CallType.OPEN_KAN, call_tiles, called_tile, discarder_index
	)
	calls.append(call)


func do_late_kan(tile: Tile) -> Array:
	hand.erase(tile)

	# Find existing pon of same type
	var pon_index: int = -1
	for i: int in range(calls.size()):
		var call: HandData.RoundStateCall = calls[i]
		if call.call_type == HandData.RoundStateCall.CallType.PON \
			and call.tiles[0].tile_type == tile.tile_type:
			pon_index = i
			break

	assert(pon_index >= 0, "do_late_kan: no matching pon found")
	var old_call: HandData.RoundStateCall = calls[pon_index]
	calls.remove_at(pon_index)

	var kan_tiles: Array = [tile]
	kan_tiles.append_array(old_call.tiles)
	var new_call: HandData.RoundStateCall = HandData.RoundStateCall.new(
		HandData.RoundStateCall.CallType.LATE_KAN, kan_tiles, tile, old_call.discarder_index
	)
	calls.append(new_call)
	return kan_tiles


func do_closed_kan(tile_type: Tile.TileType) -> Array:
	var kan_tiles: Array = []
	for tile: Tile in hand:
		if tile.tile_type == tile_type:
			kan_tiles.append(tile)
	assert(kan_tiles.size() == 4, "do_closed_kan: expected 4 tiles of type")

	for tile: Tile in kan_tiles:
		hand.erase(tile)

	var call: HandData.RoundStateCall = HandData.RoundStateCall.new(
		HandData.RoundStateCall.CallType.CLOSED_KAN, kan_tiles, null, index
	)
	calls.append(call)
	return kan_tiles


# ── Riichi ─────────────────────────────────────────────────────

func do_riichi() -> void:
	in_riichi = true
	ippatsu = true
	do_riichi_discard = true
	if first_turn:
		double_riichi = true


func can_riichi() -> bool:
	if in_riichi:
		return false
	# Can't riichi with open calls (closed kans are ok)
	for call: HandData.RoundStateCall in calls:
		if call.call_type != HandData.RoundStateCall.CallType.CLOSED_KAN:
			return false
	return TileRules.in_tenpai(hand, calls)


# ── Kan queries ────────────────────────────────────────────────

func can_late_kan() -> bool:
	if do_chii_discard or do_pon_discard or in_riichi:
		return false
	# Check if any hand tile matches a pon call
	for tile: Tile in hand:
		for call: HandData.RoundStateCall in calls:
			if call.call_type == HandData.RoundStateCall.CallType.PON \
				and call.tiles[0].tile_type == tile.tile_type:
				return true
	return false


func can_closed_kan() -> bool:
	if do_chii_discard or do_pon_discard:
		return false
	return get_closed_kan_types().size() > 0


func get_closed_kan_types() -> Array:
	var type_counts: Dictionary = {}
	for tile: Tile in hand:
		var t: int = int(tile.tile_type)
		type_counts[t] = type_counts.get(t, 0) + 1
	var result: Array = []
	for t: int in type_counts:
		if type_counts[t] == 4:
			result.append(t as Tile.TileType)
	return result


func get_kan_count() -> int:
	var count: int = 0
	for call: HandData.RoundStateCall in calls:
		if call.call_type in [
			HandData.RoundStateCall.CallType.OPEN_KAN,
			HandData.RoundStateCall.CallType.CLOSED_KAN,
			HandData.RoundStateCall.CallType.LATE_KAN
		]:
			count += 1
	return count


# ── Furiten ────────────────────────────────────────────────────

func in_furiten() -> bool:
	return temporary_furiten or TileRules.in_furiten(hand, calls, pond)


func check_temporary_furiten(tile: Tile) -> void:
	var test_hand: Array = hand.duplicate()
	test_hand.append(tile)
	if TileRules.winning_hand(test_hand, calls):
		temporary_furiten = true


# ── Flow interruption ─────────────────────────────────────────

func on_flow_interrupted() -> void:
	ippatsu = false
	first_turn = false


# ── Private helpers ────────────────────────────────────────────

func _has_tile(tile: Tile) -> bool:
	for t: Tile in hand:
		if t == tile:
			return true
	return false


## Calculate kuikae (swap-call) forbidden discard types after chii.
func _get_kuikae_types(called: Tile, t1: Tile, t2: Tile) -> Array:
	var forbidden: Array = []
	# Can't discard the same type as the called tile
	forbidden.append(called.tile_type)

	# Can't discard tiles that complete the same sequence from the other end
	var sorted: Array = Tile.sort_by_type([called, t1, t2])
	var low: int = int(sorted[0].tile_type)
	var high: int = int(sorted[2].tile_type)

	# If called tile is at the low end, the tile below it is also forbidden
	if int(called.tile_type) == low:
		var below: int = high + 1
		if below <= int(Tile.TileType.MAN9) or below <= int(Tile.TileType.PIN9) or below <= int(Tile.TileType.SOU9):
			# Only if it's the same suit
			var candidate: Tile = Tile.new(-1, below as Tile.TileType)
			if candidate.is_same_sort(called):
				forbidden.append(below as Tile.TileType)

	# If called tile is at the high end, the tile above it is also forbidden
	if int(called.tile_type) == high:
		var above: int = low - 1
		if above >= int(Tile.TileType.MAN1) or above >= int(Tile.TileType.PIN1) or above >= int(Tile.TileType.SOU1):
			var candidate: Tile = Tile.new(-1, above as Tile.TileType)
			if candidate.is_same_sort(called):
				forbidden.append(above as Tile.TileType)

	return forbidden
