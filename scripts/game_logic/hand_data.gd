## hand_data.gd — Data classes for hand analysis results.
##
## Access inner classes via HandData.TileMeld, HandData.TilePair, etc.
class_name HandData
extends RefCounted


class TileMeld:
	extends RefCounted

	var tile_1: Tile
	var tile_2: Tile
	var tile_3: Tile
	var tile_4: Tile  # null for non-kan
	var is_closed: bool
	var is_kan: bool

	func _init(t1: Tile, t2: Tile, t3: Tile, closed: bool) -> void:
		tile_1 = t1
		tile_2 = t2
		tile_3 = t3
		tile_4 = null
		is_closed = closed
		is_kan = false

	static func new_kan(t1: Tile, t2: Tile, t3: Tile, t4: Tile, closed: bool) -> TileMeld:
		var meld: TileMeld = TileMeld.new(t1, t2, t3, closed)
		meld.tile_4 = t4
		meld.is_kan = true
		return meld

	var is_triplet: bool:
		get: return tile_1.tile_type == tile_2.tile_type and tile_2.tile_type == tile_3.tile_type

	func equals(other: TileMeld) -> bool:
		if is_kan != other.is_kan:
			return false
		# Compare by sorted tile types
		var self_types: Array = [int(tile_1.tile_type), int(tile_2.tile_type), int(tile_3.tile_type)]
		var other_types: Array = [int(other.tile_1.tile_type), int(other.tile_2.tile_type), int(other.tile_3.tile_type)]
		self_types.sort()
		other_types.sort()
		return self_types == other_types


class TilePair:
	extends RefCounted

	var tile_1: Tile
	var tile_2: Tile

	func _init(t1: Tile, t2: Tile) -> void:
		tile_1 = t1
		tile_2 = t2

	func equals(other: TilePair) -> bool:
		return tile_1.tile_type == other.tile_1.tile_type


class HandReading:
	extends RefCounted

	var melds: Array = []   # Array of TileMeld
	var pairs: Array = []   # Array of TilePair
	var is_chiitoi: bool = false
	var is_kokushi: bool = false

	func equals(other: HandReading) -> bool:
		if is_chiitoi != other.is_chiitoi or is_kokushi != other.is_kokushi:
			return false
		if melds.size() != other.melds.size() or pairs.size() != other.pairs.size():
			return false

		for i: int in range(melds.size()):
			if not melds[i].equals(other.melds[i]):
				return false
		for i: int in range(pairs.size()):
			if not pairs[i].equals(other.pairs[i]):
				return false
		return true


class RoundStateCall:
	extends RefCounted

	enum CallType { CHII, PON, OPEN_KAN, CLOSED_KAN, LATE_KAN }

	var call_type: CallType
	var tiles: Array       # Array of Tile
	var call_tile: Tile    # The tile that was called (from discard)
	var discarder_index: int

	func _init(type: CallType, call_tiles: Array, called_tile: Tile, discarder: int) -> void:
		call_type = type
		tiles = call_tiles
		call_tile = called_tile
		discarder_index = discarder
