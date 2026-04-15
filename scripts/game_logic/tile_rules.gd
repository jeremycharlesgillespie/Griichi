## tile_rules.gd — Core tile analysis: call eligibility, hand decomposition,
## tenpai/shanten detection, and waiting tile calculation.
##
## This is the foundation — yaku detection and scoring will be added
## incrementally as separate files.
class_name TileRules
extends RefCounted


# ── Call eligibility ────────────────────────────────────────────

static func can_pon(hand: Array, tile: Tile) -> bool:
	var count: int = 0
	for t: Tile in hand:
		if t.tile_type == tile.tile_type:
			count += 1
			if count == 2:
				return true
	return false


static func can_open_kan(hand: Array, tile: Tile) -> bool:
	var count: int = 0
	for t: Tile in hand:
		if t.tile_type == tile.tile_type:
			count += 1
			if count == 3:
				return true
	return false


static func can_chii(hand: Array, tile: Tile) -> bool:
	return get_chii_groups(hand, tile).size() > 0


static func get_chii_groups(hand: Array, tile: Tile) -> Array:
	var groups: Array = []

	if not tile.is_suit_tile():
		return groups

	# Find same-suit tiles in hand
	var same_suit: Array = []
	for t: Tile in hand:
		if tile.is_same_sort(t):
			same_suit.append(t)

	var m2: Tile = null  # tile_type - 2
	var m1: Tile = null  # tile_type - 1
	var p1: Tile = null  # tile_type + 1
	var p2: Tile = null  # tile_type + 2

	var base_type: int = int(tile.tile_type)
	for t: Tile in same_suit:
		var diff: int = int(t.tile_type) - base_type
		match diff:
			-2: m2 = t
			-1: m1 = t
			1:  p1 = t
			2:  p2 = t

	# Middle wait: m1 + p1 (e.g., have 4-6, discard is 5)
	if m1 != null and p1 != null:
		groups.append([m1, p1])

	# Low wait: m2 + m1 (e.g., have 3-4, discard is 5)
	if m2 != null and m1 != null:
		groups.append([m2, m1])

	# High wait: p1 + p2 (e.g., have 6-7, discard is 5)
	if p1 != null and p2 != null:
		groups.append([p1, p2])

	return groups


# ── Furiten ─────────────────────────────────────────────────────

static func in_furiten(hand: Array, calls: Array, pond: Array) -> bool:
	var sorted_pond: Array = Tile.sort_by_type(pond)
	var test_hand: Array = hand.duplicate()

	for i: int in range(sorted_pond.size()):
		var tile: Tile = sorted_pond[i]

		# Skip duplicate types — already checked
		if i > 0 and tile.tile_type == sorted_pond[i - 1].tile_type:
			continue

		test_hand.append(tile)
		if winning_hand(test_hand, calls):
			return true
		test_hand.pop_back()

	return false


# ── Void hand (kyuushu kyuuhai) ─────────────────────────────────

static func can_void_hand(hand: Array) -> bool:
	var sorted_hand: Array = Tile.sort_by_type(hand)
	var unique_terminal_honor_count: int = 0

	for i: int in range(sorted_hand.size()):
		var tile: Tile = sorted_hand[i]
		if i > 0 and sorted_hand[i - 1].tile_type == tile.tile_type:
			continue
		if tile.is_terminal_tile() or tile.is_honor_tile():
			unique_terminal_honor_count += 1

	return unique_terminal_honor_count >= 9


# ── Hand analysis ───────────────────────────────────────────────

static func in_tenpai(hand: Array, calls: Array) -> bool:
	return hand_readings(hand, calls, true, true).size() > 0


static func winning_hand(hand: Array, calls: Array) -> bool:
	return hand_readings(hand, calls, false, true).size() > 0


## The core hand decomposition engine. Finds all valid ways to read
## a hand as 4 melds + 1 pair (plus chiitoi and kokushi special forms).
##
## tenpai_only: if true, adds a virtual "any tile" to test for tenpai
## early_return: if true, stops after finding the first valid reading
static func hand_readings(hand: Array, calls: Array, tenpai_only: bool, early_return: bool) -> Array:
	var call_melds: Array = []

	if calls != null:
		for call in calls:
			var sorted_tiles: Array = Tile.sort_by_type(call.tiles)
			var meld: HandData.TileMeld = null
			if call.call_type == HandData.RoundStateCall.CallType.CHII or call.call_type == HandData.RoundStateCall.CallType.PON:
				meld = HandData.TileMeld.new(sorted_tiles[0], sorted_tiles[1], sorted_tiles[2], false)
			elif call.call_type == HandData.RoundStateCall.CallType.OPEN_KAN or call.call_type == HandData.RoundStateCall.CallType.LATE_KAN:
				meld = HandData.TileMeld.new_kan(sorted_tiles[0], sorted_tiles[1], sorted_tiles[2], sorted_tiles[3], false)
			elif call.call_type == HandData.RoundStateCall.CallType.CLOSED_KAN:
				meld = HandData.TileMeld.new_kan(sorted_tiles[0], sorted_tiles[1], sorted_tiles[2], sorted_tiles[3], true)
			if meld != null:
				call_melds.append(meld)

	return _hand_reading_recursion(hand, call_melds, tenpai_only, early_return)


static func _hand_reading_recursion(remaining: Array, melds: Array, tenpai_only: bool, early_return: bool) -> Array:
	var readings: Array = []
	var sorted: Array = Tile.sort_by_type(remaining)

	# Base case: no tiles left → valid complete hand
	if sorted.size() == 0:
		var reading: HandData.HandReading = HandData.HandReading.new()
		reading.melds = melds.duplicate()
		readings.append(reading)
		return readings

	# Tenpai check: if tenpai_only, try adding each of the 34 tile types
	# and recursing with tenpai_only=false
	if tenpai_only:
		var tried_types: Dictionary = {}
		for raw_type: int in range(int(Tile.TileType.MAN1), int(Tile.TileType.CHUN) + 1):
			if tried_types.has(raw_type):
				continue
			tried_types[raw_type] = true

			var test_tile: Tile = Tile.new(-1, raw_type as Tile.TileType)
			var test_hand: Array = sorted.duplicate()
			test_hand.append(test_tile)

			var sub_readings: Array = _hand_reading_recursion(test_hand, melds, false, early_return)
			for r: HandData.HandReading in sub_readings:
				_append_reading(readings, r)
				if early_return and readings.size() > 0:
					return readings

		# Also check chiitoi and kokushi for tenpai
		_check_chiitoi_tenpai(sorted, melds, readings, early_return)
		if early_return and readings.size() > 0:
			return readings
		_check_kokushi_tenpai(sorted, melds, readings, early_return)
		return readings

	# Standard decomposition: try to form melds from the first tile
	if sorted.size() >= 2:
		# Try pair
		if sorted[0].tile_type == sorted[1].tile_type:
			var pair: HandData.TilePair = HandData.TilePair.new(sorted[0], sorted[1])
			var rest: Array = sorted.slice(2)
			var new_melds: Array = melds.duplicate()
			# Check if remaining can form melds (pairs go into a separate list)
			var sub: Array = _try_with_pair(rest, new_melds, pair, early_return)
			for r: HandData.HandReading in sub:
				_append_reading(readings, r)
				if early_return and readings.size() > 0:
					return readings

	if sorted.size() >= 3:
		# Try triplet
		if sorted[0].tile_type == sorted[1].tile_type and sorted[1].tile_type == sorted[2].tile_type:
			var meld: HandData.TileMeld = HandData.TileMeld.new(sorted[0], sorted[1], sorted[2], true)
			var rest: Array = sorted.slice(3)
			var new_melds: Array = melds.duplicate()
			new_melds.append(meld)
			var sub: Array = _hand_reading_recursion(rest, new_melds, false, early_return)
			for r: HandData.HandReading in sub:
				_append_reading(readings, r)
				if early_return and readings.size() > 0:
					return readings

		# Try sequence (only for suit tiles)
		if sorted[0].is_suit_tile():
			var t1: Tile = sorted[0]
			var t2: Tile = _find_tile_of_type(sorted, int(t1.tile_type) + 1, 1)
			var t3: Tile = _find_tile_of_type(sorted, int(t1.tile_type) + 2, 1)

			if t2 != null and t3 != null:
				var meld: HandData.TileMeld = HandData.TileMeld.new(t1, t2, t3, true)
				var rest: Array = sorted.duplicate()
				rest.erase(t1)
				rest.erase(t2)
				rest.erase(t3)
				var new_melds: Array = melds.duplicate()
				new_melds.append(meld)
				var sub: Array = _hand_reading_recursion(rest, new_melds, false, early_return)
				for r: HandData.HandReading in sub:
					_append_reading(readings, r)
					if early_return and readings.size() > 0:
						return readings

	# Chiitoi (7 pairs) check
	_check_chiitoi(sorted, melds, readings, early_return)
	if early_return and readings.size() > 0:
		return readings

	# Kokushi check
	_check_kokushi(sorted, melds, readings, early_return)

	return readings


static func _try_with_pair(remaining: Array, melds: Array, pair: HandData.TilePair, early_return: bool) -> Array:
	var readings: Array = []

	if remaining.size() == 0:
		var reading: HandData.HandReading = HandData.HandReading.new()
		reading.melds = melds.duplicate()
		reading.pairs = [pair]
		readings.append(reading)
		return readings

	if remaining.size() < 3:
		return readings

	var sorted: Array = Tile.sort_by_type(remaining)

	# Try triplet
	if sorted.size() >= 3 and sorted[0].tile_type == sorted[1].tile_type and sorted[1].tile_type == sorted[2].tile_type:
		var meld: HandData.TileMeld = HandData.TileMeld.new(sorted[0], sorted[1], sorted[2], true)
		var rest: Array = sorted.slice(3)
		var new_melds: Array = melds.duplicate()
		new_melds.append(meld)
		var sub: Array = _try_with_pair(rest, new_melds, pair, early_return)
		for r: HandData.HandReading in sub:
			_append_reading(readings, r)
			if early_return and readings.size() > 0:
				return readings

	# Try sequence
	if sorted[0].is_suit_tile():
		var t1: Tile = sorted[0]
		var t2: Tile = _find_tile_of_type(sorted, int(t1.tile_type) + 1, 1)
		var t3: Tile = _find_tile_of_type(sorted, int(t1.tile_type) + 2, 1)

		if t2 != null and t3 != null:
			var meld: HandData.TileMeld = HandData.TileMeld.new(t1, t2, t3, true)
			var rest: Array = sorted.duplicate()
			rest.erase(t1)
			rest.erase(t2)
			rest.erase(t3)
			var new_melds: Array = melds.duplicate()
			new_melds.append(meld)
			var sub: Array = _try_with_pair(rest, new_melds, pair, early_return)
			for r: HandData.HandReading in sub:
				_append_reading(readings, r)
				if early_return and readings.size() > 0:
					return readings

	return readings


static func _find_tile_of_type(tiles: Array, type_int: int, skip: int) -> Tile:
	var skipped: int = 0
	for t: Tile in tiles:
		if int(t.tile_type) == type_int:
			skipped += 1
			if skipped >= skip:
				return t
	return null


static func _append_reading(readings: Array, reading: HandData.HandReading) -> void:
	# Deduplicate
	for existing: HandData.HandReading in readings:
		if existing.equals(reading):
			return
	readings.append(reading)


# ── Chiitoi (7 pairs) ──────────────────────────────────────────

static func _check_chiitoi(sorted: Array, melds: Array, readings: Array, early_return: bool) -> void:
	# Chiitoi needs exactly 14 tiles, no calls
	if sorted.size() != 14 or melds.size() > 0:
		return

	var pairs: Array = []
	var i: int = 0
	while i < sorted.size() - 1:
		if sorted[i].tile_type == sorted[i + 1].tile_type:
			pairs.append(HandData.TilePair.new(sorted[i], sorted[i + 1]))
			i += 2
		else:
			return  # unpaired tile — not chiitoi
		if i >= sorted.size():
			break

	if pairs.size() == 7:
		var reading: HandData.HandReading = HandData.HandReading.new()
		reading.is_chiitoi = true
		reading.pairs = pairs
		reading.melds = melds.duplicate()
		_append_reading(readings, reading)


static func _check_chiitoi_tenpai(sorted: Array, melds: Array, readings: Array, early_return: bool) -> void:
	if sorted.size() != 13 or melds.size() > 0:
		return

	# Try adding each of the 34 types and check chiitoi
	var tried: Dictionary = {}
	for raw_type: int in range(int(Tile.TileType.MAN1), int(Tile.TileType.CHUN) + 1):
		if tried.has(raw_type):
			continue
		tried[raw_type] = true

		var test: Array = sorted.duplicate()
		test.append(Tile.new(-1, raw_type as Tile.TileType))
		_check_chiitoi(Tile.sort_by_type(test), melds, readings, early_return)
		if early_return and readings.size() > 0:
			return


# ── Kokushi ─────────────────────────────────────────────────────

const KOKUSHI_TYPES: Array[Tile.TileType] = [
	Tile.TileType.MAN1, Tile.TileType.MAN9,
	Tile.TileType.PIN1, Tile.TileType.PIN9,
	Tile.TileType.SOU1, Tile.TileType.SOU9,
	Tile.TileType.TON, Tile.TileType.NAN, Tile.TileType.SHAA, Tile.TileType.PEI,
	Tile.TileType.HAKU, Tile.TileType.HATSU, Tile.TileType.CHUN
]


static func _check_kokushi(sorted: Array, melds: Array, readings: Array, early_return: bool) -> void:
	if sorted.size() != 14 or melds.size() > 0:
		return

	# Must have one of each kokushi type + one duplicate
	var type_counts: Dictionary = {}
	for tile: Tile in sorted:
		var t: int = int(tile.tile_type)
		type_counts[t] = type_counts.get(t, 0) + 1

	for kt: Tile.TileType in KOKUSHI_TYPES:
		if type_counts.get(int(kt), 0) == 0:
			return

	# All 13 types present — check total is 14
	var total: int = 0
	for kt: Tile.TileType in KOKUSHI_TYPES:
		total += type_counts.get(int(kt), 0)
	if total != 14:
		return

	var reading: HandData.HandReading = HandData.HandReading.new()
	reading.is_kokushi = true
	reading.melds = melds.duplicate()
	_append_reading(readings, reading)


static func _check_kokushi_tenpai(sorted: Array, melds: Array, readings: Array, early_return: bool) -> void:
	if sorted.size() != 13 or melds.size() > 0:
		return

	for raw_type: int in range(int(Tile.TileType.MAN1), int(Tile.TileType.CHUN) + 1):
		var test: Array = sorted.duplicate()
		test.append(Tile.new(-1, raw_type as Tile.TileType))
		_check_kokushi(Tile.sort_by_type(test), melds, readings, early_return)
		if early_return and readings.size() > 0:
			return


# ── Shanten + waits (from our earlier work) ────────────────────

static func get_shanten(hand: Array, calls: Array) -> int:
	var post_draw: bool = (hand.size() % 3) == 2
	if post_draw:
		# 14-tile hand: check if any single discard leaves us tenpai
		var seen_types: Dictionary = {}
		for d: Tile in hand:
			if seen_types.has(int(d.tile_type)):
				continue
			seen_types[int(d.tile_type)] = true

			var reduced: Array = hand.duplicate()
			reduced.erase(d)
			if in_tenpai(reduced, calls):
				return 0
		# Not tenpai — use fast estimate
		return _estimate_shanten(hand, calls)

	# 13-tile hand: check tenpai directly
	if in_tenpai(hand, calls):
		return 0
	return _estimate_shanten(hand, calls)


## Fast shanten estimate using mentsu/pair counting heuristic.
## Counts useful groups (pairs, partial sequences, triplets) and estimates
## distance to a complete hand. Much faster than brute-force tile swapping.
static func _estimate_shanten(hand: Array, calls: Array) -> int:
	var tiles: Array = hand.duplicate()

	# Count how many melds are provided by calls
	var call_melds: int = 0
	if calls != null:
		for call in calls:
			call_melds += 1

	# We need (4 - call_melds) melds + 1 pair from the hand tiles
	var needed_melds: int = 4 - call_melds

	# Count tile types
	var type_counts: Dictionary = {}
	for tile: Tile in tiles:
		var t: int = int(tile.tile_type)
		type_counts[t] = type_counts.get(t, 0) + 1

	# Greedily count complete groups, then partial groups
	var complete_melds: int = 0
	var pairs: int = 0
	var partial: int = 0  # Pairs or adjacent tiles that could become melds

	# Work on a copy of counts
	var counts: Dictionary = type_counts.duplicate()

	# 1. Extract triplets
	for t: int in counts.keys():
		while counts[t] >= 3 and complete_melds < needed_melds:
			counts[t] -= 3
			complete_melds += 1

	# 2. Extract sequences (suit tiles only)
	for base: int in [int(Tile.TileType.MAN1), int(Tile.TileType.PIN1), int(Tile.TileType.SOU1)]:
		for offset: int in range(7):  # 1-7 can start a sequence
			var t1: int = base + offset
			var t2: int = base + offset + 1
			var t3: int = base + offset + 2
			while counts.get(t1, 0) >= 1 and counts.get(t2, 0) >= 1 and counts.get(t3, 0) >= 1 \
				and complete_melds < needed_melds:
				counts[t1] -= 1
				counts[t2] -= 1
				counts[t3] -= 1
				complete_melds += 1

	# 3. Count pairs
	for t: int in counts.keys():
		if counts[t] >= 2:
			pairs += 1
			counts[t] -= 2

	# 4. Count partial sequences (adjacent tiles)
	for base: int in [int(Tile.TileType.MAN1), int(Tile.TileType.PIN1), int(Tile.TileType.SOU1)]:
		for offset: int in range(8):
			var t1: int = base + offset
			var t2: int = base + offset + 1
			if counts.get(t1, 0) >= 1 and counts.get(t2, 0) >= 1:
				counts[t1] -= 1
				counts[t2] -= 1
				partial += 1

	# Shanten formula: (needed_melds - complete_melds) * 2 - partial_groups - has_pair
	var useful_partial: int = mini(partial + pairs, needed_melds - complete_melds)
	var has_pair: int = 1 if pairs > 0 else 0
	var shanten: int = (needed_melds - complete_melds) * 2 - useful_partial - has_pair + 1

	# Clamp: 0 means tenpai (already checked above), minimum is 1
	return maxi(shanten, 1)


static func waiting_tiles(hand: Array, calls: Array) -> Array:
	var waits: Array = []
	for raw_type: int in range(int(Tile.TileType.MAN1), int(Tile.TileType.CHUN) + 1):
		var candidate: Tile = Tile.new(-1, raw_type as Tile.TileType)
		if can_win_with(hand, calls, candidate):
			waits.append(candidate)
	return waits


static func can_win_with(hand: Array, calls: Array, tile: Tile) -> bool:
	var test: Array = hand.duplicate()
	test.append(tile)
	return winning_hand(test, calls)
