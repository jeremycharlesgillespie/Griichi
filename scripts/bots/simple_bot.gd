## simple_bot.gd — Mid-tier bot with discard heuristics.
##
## Priority: keep tenpai > dump isolated honors > dump terminals > dump orphans.
## Calls pon on yakuhai only. Never calls chii.
class_name SimpleBot
extends Bot


func get_discard_tile(player: RoundStatePlayer, round_state: RoundState) -> Tile:
	var hand: Array = player.hand
	var discardable: Array = player.get_discard_tiles()

	if discardable.size() == 0:
		return player.newest_tile
	if discardable.size() == 1:
		return discardable[0]

	# 1. If tenpai, discard a tile that keeps us tenpai
	var tenpai_discard: Tile = _find_tenpai_preserving_discard(discardable, hand, player.calls)
	if tenpai_discard != null:
		return tenpai_discard

	# 2. Useless honors: winds that don't match seat or round wind, solo dragons
	var useless_honor: Tile = _find_useless_honor(discardable, hand, player.wind, round_state.round_wind)
	if useless_honor != null:
		return useless_honor

	# 3. Isolated tiles (no neighbors in hand)
	var isolated: Tile = _find_isolated_tile(discardable, hand)
	if isolated != null:
		return isolated

	# 4. Tiles with only distant neighbors (gap of 2)
	var distant: Tile = _find_distant_neighbor_tile(discardable, hand)
	if distant != null:
		return distant

	# 5. Terminals over middle tiles
	var terminal: Tile = _find_terminal(discardable)
	if terminal != null:
		return terminal

	# 6. Fallback: first discardable
	return discardable[0]


func should_call_pon(player: RoundStatePlayer, round_state: RoundState) -> bool:
	var tile: Tile = round_state.discard_tile
	if tile == null:
		return false

	# Only pon yakuhai: dragons, seat wind, round wind
	if tile.is_dragon_tile():
		return true
	if tile.is_wind(player.wind):
		return true
	if tile.is_wind(round_state.round_wind):
		return true

	return false


# ── Private helpers ────────────────────────────────────────────

func _find_tenpai_preserving_discard(discardable: Array, hand: Array, calls: Array) -> Tile:
	for tile: Tile in discardable:
		var reduced: Array = hand.duplicate()
		reduced.erase(tile)
		if TileRules.in_tenpai(reduced, calls):
			return tile
	return null


func _find_useless_honor(discardable: Array, hand: Array, seat_wind: Tile.Wind, round_w: Tile.Wind) -> Tile:
	for tile: Tile in discardable:
		if not tile.is_honor_tile():
			continue
		var count: int = _count_type(hand, tile.tile_type)
		if count >= 2:
			continue  # Pair — might be useful

		# Solo wind that doesn't match seat or round
		if tile.is_wind_tile():
			if not tile.is_wind(seat_wind) and not tile.is_wind(round_w):
				return tile

		# Solo dragon
		if tile.is_dragon_tile() and count == 1:
			return tile

	return null


func _find_isolated_tile(discardable: Array, hand: Array) -> Tile:
	for tile: Tile in discardable:
		if tile.is_honor_tile():
			continue
		var has_neighbor: bool = false
		for other: Tile in hand:
			if other == tile:
				continue
			if tile.is_neighbour(other) or tile.tile_type == other.tile_type:
				has_neighbor = true
				break
		if not has_neighbor:
			return tile
	return null


func _find_distant_neighbor_tile(discardable: Array, hand: Array) -> Tile:
	for tile: Tile in discardable:
		if tile.is_honor_tile():
			continue
		var has_close: bool = false
		for other: Tile in hand:
			if other == tile:
				continue
			if tile.is_neighbour(other) or tile.tile_type == other.tile_type:
				has_close = true
				break
		if not has_close:
			# Check if it has a distant (gap-1) neighbor
			var has_distant: bool = false
			for other: Tile in hand:
				if other == tile:
					continue
				if tile.is_second_neighbour(other):
					has_distant = true
					break
			if has_distant:
				return tile
	return null


func _find_terminal(discardable: Array) -> Tile:
	for tile: Tile in discardable:
		if tile.is_terminal_tile():
			return tile
	return null


func _count_type(hand: Array, tt: Tile.TileType) -> int:
	var count: int = 0
	for tile: Tile in hand:
		if tile.tile_type == tt:
			count += 1
	return count
