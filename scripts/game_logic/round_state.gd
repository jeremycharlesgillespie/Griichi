## round_state.gd — Single-round game state machine.
##
## Manages the tile wall, 4 players, draw/discard cycle, calls (pon/chii/kan),
## riichi, win detection (ron/tsumo), and draw conditions.
class_name RoundState
extends RefCounted


# ── Enums ──────────────────────────────────────────────────────

enum GameDrawType {
	NONE,
	EMPTY_WALL,
	FOUR_KANS,
	FOUR_RIICHI,
	FOUR_WINDS,
	TRIPLE_RON,
	VOID_HAND
}

enum ChankanCall { NONE, LATE, CLOSED }


# ── Properties ─────────────────────────────────────────────────

var players: Array = []            # Array of RoundStatePlayer (4)
var wall: RoundStateWall = null
var round_wind: Tile.Wind = Tile.Wind.EAST
var dealer: int = 0

var current_index: int = 0
var winner_indices: Array = []
var game_over: bool = false
var game_draw_type: int = GameDrawType.NONE
var flow_interrupted: bool = false
var turn_counter: int = 1
var rinshan: bool = false
var chankan_call: int = ChankanCall.NONE
var riichi_return_index: int = -1
var discard_tile: Tile = null


# ── Accessors ──────────────────────────────────────────────────

var current_player: RoundStatePlayer:
	get: return players[current_index]

var tiles_empty: bool:
	get: return wall.empty


# ── Initialization ─────────────────────────────────────────────

func _init(wind: Tile.Wind, dealer_index: int) -> void:
	round_wind = wind
	dealer = dealer_index
	current_index = dealer

	wall = RoundStateWall.new()
	wall.build_and_shuffle()

	for i: int in range(4):
		var player_wind: Tile.Wind = Tile.int_to_wind((i - dealer + 4) % 4)
		var is_dealer: bool = (i == dealer)
		var player: RoundStatePlayer = RoundStatePlayer.new(i, player_wind, is_dealer)
		players.append(player)


## Deal initial hands: 3 rounds of 4 tiles each, then 1 tile each.
## All players get 13 tiles. Dealer then draws the 14th (first draw).
func start() -> void:
	# 3 rounds of 4 tiles
	for _round: int in range(3):
		for offset: int in range(4):
			var player_index: int = (dealer + offset) % 4
			for _t: int in range(4):
				var tile: Tile = wall.draw_wall()
				players[player_index].draw(tile)

	# 1 tile each
	for offset: int in range(4):
		var player_index: int = (dealer + offset) % 4
		var tile: Tile = wall.draw_wall()
		players[player_index].draw(tile)

	# Dealer draws the 14th tile (first turn draw)
	var first_tile: Tile = wall.draw_wall()
	players[dealer].draw(first_tile)


# ── Draw phase ─────────────────────────────────────────────────

func tile_draw() -> Tile:
	var tile: Tile = wall.draw_wall()
	current_player.draw(tile)
	return tile


func tile_draw_dead_wall() -> Tile:
	var tile: Tile = wall.draw_dead_wall()
	current_player.draw(tile)
	return tile


# ── Discard phase ──────────────────────────────────────────────

func tile_discard(tile: Tile) -> bool:
	if not current_player.can_discard(tile):
		return false
	current_player.discard(tile)
	discard_tile = tile
	rinshan = false
	chankan_call = ChankanCall.NONE
	return true


# ── Call handling ──────────────────────────────────────────────

func pon(player_index: int, tile_1: Tile, tile_2: Tile) -> void:
	var caller: RoundStatePlayer = players[player_index]
	var discarder: RoundStatePlayer = current_player

	discarder.rob_tile(discard_tile)
	caller.do_pon(current_index, discard_tile, tile_1, tile_2)
	_interrupt_flow()
	current_index = player_index


func chii(player_index: int, tile_1: Tile, tile_2: Tile) -> void:
	var caller: RoundStatePlayer = players[player_index]
	var discarder: RoundStatePlayer = current_player

	discarder.rob_tile(discard_tile)
	caller.do_chii(current_index, discard_tile, tile_1, tile_2)
	_interrupt_flow()
	current_index = player_index


func open_kan(player_index: int, tile_1: Tile, tile_2: Tile, tile_3: Tile) -> void:
	var caller: RoundStatePlayer = players[player_index]
	var discarder: RoundStatePlayer = current_player

	discarder.rob_tile(discard_tile)
	caller.do_open_kan(current_index, discard_tile, tile_1, tile_2, tile_3)
	current_index = player_index
	_do_kan()


func late_kan(tile: Tile) -> Array:
	var tiles: Array = current_player.do_late_kan(tile)
	chankan_call = ChankanCall.LATE
	discard_tile = tile
	return tiles


func closed_kan(tile_type: Tile.TileType) -> Array:
	var tiles: Array = current_player.do_closed_kan(tile_type)
	chankan_call = ChankanCall.CLOSED
	discard_tile = tiles[0]
	return tiles


func _do_kan() -> void:
	rinshan = true
	wall.flip_dora()
	tile_draw_dead_wall()
	_interrupt_flow()


func _interrupt_flow() -> void:
	for player: RoundStatePlayer in players:
		player.on_flow_interrupted()
	flow_interrupted = true
	riichi_return_index = -1


# ── Win conditions ─────────────────────────────────────────────

func ron(indices: Array) -> void:
	game_over = true
	winner_indices = indices
	game_draw_type = GameDrawType.NONE


func tsumo() -> void:
	game_over = true
	winner_indices = [current_index]
	game_draw_type = GameDrawType.NONE


# ── Riichi ─────────────────────────────────────────────────────

func riichi() -> bool:
	if not can_riichi():
		return false
	riichi_return_index = current_index
	current_player.do_riichi()
	return true


# ── Turn flow ──────────────────────────────────────────────────

## Called after all call decisions are resolved for a discard.
## Checks draw conditions, then advances to the next player.
func calls_finished() -> void:
	if chankan_call == ChankanCall.NONE:
		# Check draw conditions
		if wall.empty:
			game_over = true
			game_draw_type = GameDrawType.EMPTY_WALL
			return

		var total_kans: int = 0
		var kan_player: int = -1
		var different_kan_players: bool = false
		for player: RoundStatePlayer in players:
			var player_kans: int = player.get_kan_count()
			if player_kans > 0:
				if kan_player >= 0 and kan_player != player.index:
					different_kan_players = true
				kan_player = player.index
				total_kans += player_kans

		if total_kans >= 4 and different_kan_players:
			game_over = true
			game_draw_type = GameDrawType.FOUR_KANS
			return

		var riichi_count: int = 0
		for player: RoundStatePlayer in players:
			if player.in_riichi:
				riichi_count += 1
		if riichi_count == 4:
			game_over = true
			game_draw_type = GameDrawType.FOUR_RIICHI
			return

		if turn_counter == 4 and not flow_interrupted:
			if _check_four_winds():
				game_over = true
				game_draw_type = GameDrawType.FOUR_WINDS
				return
	else:
		# After a kan, do the kan sequence
		_do_kan()

	turn_counter += 1
	riichi_return_index = -1
	chankan_call = ChankanCall.NONE


## Advance to the next player (called by game controller after discard + calls).
func advance_turn() -> void:
	current_index = (current_index + 1) % 4


func _check_four_winds() -> bool:
	if players[0].pond.size() == 0:
		return false
	var first_type: Tile.TileType = players[0].pond[0].tile_type
	if not players[0].pond[0].is_wind_tile():
		return false
	for i: int in range(1, 4):
		if players[i].pond.size() == 0:
			return false
		if players[i].pond[0].tile_type != first_type:
			return false
	return true


# ── Query methods ──────────────────────────────────────────────

func can_tsumo() -> bool:
	return TileRules.winning_hand(current_player.hand, _get_calls_for_rules(current_index))


func can_ron(player_index: int) -> bool:
	if player_index == current_index:
		return false
	var player: RoundStatePlayer = players[player_index]
	if player.in_furiten():
		return false
	var test_hand: Array = player.hand.duplicate()
	test_hand.append(discard_tile)
	return TileRules.winning_hand(test_hand, _get_calls_for_rules(player_index))


func can_riichi() -> bool:
	return wall.can_riichi and current_player.can_riichi()


func can_void_hand() -> bool:
	return not flow_interrupted and turn_counter <= 4 \
		and TileRules.can_void_hand(current_player.hand)


func can_pon(player_index: int) -> bool:
	if player_index == current_index:
		return false
	var player: RoundStatePlayer = players[player_index]
	if player.in_riichi:
		return false
	return wall.can_call and TileRules.can_pon(player.hand, discard_tile)


func can_chii(player_index: int) -> bool:
	if (current_index + 1) % 4 != player_index:
		return false
	var player: RoundStatePlayer = players[player_index]
	if player.in_riichi:
		return false
	return wall.can_call and TileRules.can_chii(player.hand, discard_tile)


func can_open_kan(player_index: int) -> bool:
	if player_index == current_index:
		return false
	var player: RoundStatePlayer = players[player_index]
	if player.in_riichi:
		return false
	return wall.can_call and wall.can_kan \
		and TileRules.can_open_kan(player.hand, discard_tile)


func can_late_kan() -> bool:
	return wall.can_call and wall.can_kan \
		and current_player.can_late_kan()


func can_closed_kan() -> bool:
	return wall.can_call and wall.can_kan \
		and current_player.can_closed_kan()


func get_tenpai_players() -> Array:
	var result: Array = []
	for player: RoundStatePlayer in players:
		if TileRules.in_tenpai(player.hand, _get_calls_for_rules(player.index)):
			result.append(player.index)
	return result


func _get_calls_for_rules(player_index: int) -> Array:
	return players[player_index].calls
