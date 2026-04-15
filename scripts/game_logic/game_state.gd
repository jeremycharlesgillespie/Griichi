## game_state.gd — Multi-round game state (hanchan).
## Manages scoring between rounds, dealer rotation, wind progression,
## and game completion.
class_name GameState
extends RefCounted


# ── Constants ──────────────────────────────────────────────────

const STARTING_SCORE: int = 25000
const ROUND_COUNT: int = 8          # East + South rounds (4 each)


# ── Properties ─────────────────────────────────────────────────

var player_scores: Array = [25000, 25000, 25000, 25000]
var player_names: Array = ["Player", "Bot East", "Bot South", "Bot West"]

var round_wind: Tile.Wind = Tile.Wind.EAST
var dealer_index: int = 0
var current_round: int = 0
var renchan: int = 0                 # Consecutive dealer wins
var riichi_sticks: int = 0           # Unclaimed 1000-point sticks
var game_is_finished: bool = false

var current_round_state: RoundState = null


# ── Round lifecycle ────────────────────────────────────────────

func start_new_round() -> RoundState:
	current_round_state = RoundState.new(round_wind, dealer_index)
	current_round_state.start()
	return current_round_state


## Process round results and update scores.
## Returns true if the game continues, false if finished.
func finish_round(round_state: RoundState) -> bool:
	if round_state.game_draw_type == RoundState.GameDrawType.NONE:
		# Someone won
		_process_win(round_state)
	else:
		# Draw
		_process_draw(round_state)

	# Check if any player is below zero
	for score: int in player_scores:
		if score < 0:
			game_is_finished = true
			return false

	# Check if all rounds are done
	if current_round + 1 >= ROUND_COUNT:
		game_is_finished = true
		return false

	return true


## Advance to the next round (call after finish_round returns true).
func advance_round(do_renchan: bool) -> void:
	if do_renchan:
		renchan += 1
		# Dealer stays, no rotation
		return

	renchan = 0
	current_round += 1
	dealer_index = (dealer_index + 1) % 4

	# Wind changes every 4 rounds
	if current_round % 4 == 0:
		round_wind = Tile.next_wind(round_wind)


# ── Score processing ───────────────────────────────────────────

func _process_win(round_state: RoundState) -> void:
	var winner_index: int = round_state.winner_indices[0]
	var is_tsumo: bool = round_state.winner_indices.size() == 1 \
		and round_state.current_index == winner_index

	if is_tsumo:
		_process_tsumo(round_state, winner_index)
	else:
		_process_ron(round_state)


func _process_tsumo(round_state: RoundState, winner_index: int) -> void:
	var winner_is_dealer: bool = (winner_index == round_state.dealer)

	# Simple scoring: use hand reading to determine base points
	var base_points: int = _calculate_hand_points(round_state, winner_index, true)

	var total_gain: int = 0
	for i: int in range(4):
		if i == winner_index:
			continue
		var payment: int = 0
		if winner_is_dealer:
			# Dealer tsumo: all pay equally (2x non-dealer rate)
			payment = _round_up_hundred(base_points * 2)
		else:
			if players_is_dealer(i):
				payment = _round_up_hundred(base_points * 2)
			else:
				payment = _round_up_hundred(base_points)

		# Add renchan bonus
		payment += renchan * 100

		player_scores[i] -= payment
		total_gain += payment

	# Winner gains all payments + riichi sticks
	player_scores[winner_index] += total_gain + riichi_sticks * 1000
	riichi_sticks = 0


func _process_ron(round_state: RoundState) -> void:
	var loser_index: int = round_state.current_index

	for winner_index: int in round_state.winner_indices:
		var base_points: int = _calculate_hand_points(round_state, winner_index, false)

		var multiplier: int = 4
		if players_is_dealer(winner_index):
			multiplier = 6

		var payment: int = _round_up_hundred(base_points * multiplier)
		payment += renchan * 300

		player_scores[loser_index] -= payment
		player_scores[winner_index] += payment

	# First winner gets riichi sticks
	player_scores[round_state.winner_indices[0]] += riichi_sticks * 1000
	riichi_sticks = 0


func _process_draw(round_state: RoundState) -> void:
	if round_state.game_draw_type != RoundState.GameDrawType.EMPTY_WALL:
		return

	# Tenpai payments on exhaustive draw
	var tenpai_indices: Array = round_state.get_tenpai_players()
	var tenpai_count: int = tenpai_indices.size()

	if tenpai_count == 0 or tenpai_count == 4:
		return  # Nobody or everybody — no payments

	var total_pool: int = 3000
	var tenpai_gain: int = total_pool / tenpai_count
	var noten_loss: int = total_pool / (4 - tenpai_count)

	for i: int in range(4):
		if i in tenpai_indices:
			player_scores[i] += tenpai_gain
		else:
			player_scores[i] -= noten_loss


## Calculate hand points (simplified scoring).
## Returns base points which get multiplied by player counts/dealer status.
func _calculate_hand_points(round_state: RoundState, winner_index: int, is_tsumo: bool) -> int:
	var player: RoundStatePlayer = round_state.players[winner_index]
	var win_hand: Array = player.hand.duplicate()
	var win_calls: Array = player.calls

	# Count han (simplified — count basic yaku)
	var han: int = _count_han(round_state, winner_index, is_tsumo)

	# Base points from han
	if han >= 13:
		return 8000   # Yakuman
	if han >= 11:
		return 6000   # Sanbaiman
	if han >= 8:
		return 4000   # Baiman
	if han >= 6:
		return 3000   # Haneman
	if han >= 5:
		return 2000   # Mangan

	# Below mangan: 30 fu base (simplified)
	var fu: int = 30
	var base: int = fu * int(pow(2, 2 + han))
	if base >= 2000:
		return 2000   # Mangan cap
	return base


## Count han for a winning hand (simplified yaku detection).
func _count_han(round_state: RoundState, winner_index: int, is_tsumo: bool) -> int:
	var player: RoundStatePlayer = round_state.players[winner_index]
	var test_hand: Array = player.hand.duplicate()
	var win_calls: Array = player.calls

	var readings: Array = TileRules.hand_readings(test_hand, win_calls, false, true)
	if readings.size() == 0:
		return 1  # Fallback: at least 1 han if winning

	var reading: HandData.HandReading = readings[0]
	var han: int = 0
	var is_closed: bool = _hand_is_closed(win_calls)

	# Riichi
	if player.in_riichi:
		han += 1
		if player.double_riichi:
			han += 1
		if player.ippatsu:
			han += 1

	# Tsumo (closed only)
	if is_tsumo and is_closed:
		han += 1  # Menzen tsumo

	# Chiitoi
	if reading.is_chiitoi:
		han += 2
		return han

	# Kokushi
	if reading.is_kokushi:
		han += 13
		return han

	# Yakuhai: value tiles in triplets
	for meld: HandData.TileMeld in reading.melds:
		if not meld.is_triplet:
			continue
		var tt: Tile.TileType = meld.tile_1.tile_type
		# Dragons
		if tt in [Tile.TileType.HAKU, Tile.TileType.HATSU, Tile.TileType.CHUN]:
			han += 1
		# Seat wind
		if _tile_is_wind(tt, player.wind):
			han += 1
		# Round wind
		if _tile_is_wind(tt, round_state.round_wind):
			han += 1

	# Tanyao (all simples)
	var all_simples: bool = true
	for tile: Tile in test_hand:
		if tile.is_terminal_tile() or tile.is_honor_tile():
			all_simples = false
			break
	if all_simples:
		for call: HandData.RoundStateCall in win_calls:
			for tile: Tile in call.tiles:
				if tile.is_terminal_tile() or tile.is_honor_tile():
					all_simples = false
					break
	if all_simples:
		han += 1

	# Pinfu (all sequences, no-value pair, two-sided wait, closed)
	if is_closed and _check_pinfu(reading, player.wind, round_state.round_wind):
		han += 1

	# Iipeiko (two identical sequences, closed only)
	if is_closed:
		han += _count_iipeiko(reading)

	# Ensure at least 1 han
	if han == 0:
		han = 1

	return han


func _hand_is_closed(win_calls: Array) -> bool:
	for call: HandData.RoundStateCall in win_calls:
		if call.call_type != HandData.RoundStateCall.CallType.CLOSED_KAN:
			return false
	return true


func _tile_is_wind(tt: Tile.TileType, w: Tile.Wind) -> bool:
	match w:
		Tile.Wind.EAST:  return tt == Tile.TileType.TON
		Tile.Wind.SOUTH: return tt == Tile.TileType.NAN
		Tile.Wind.WEST:  return tt == Tile.TileType.SHAA
		Tile.Wind.NORTH: return tt == Tile.TileType.PEI
	return false


func _check_pinfu(reading: HandData.HandReading, seat_wind: Tile.Wind, round_w: Tile.Wind) -> bool:
	# All melds must be sequences
	for meld: HandData.TileMeld in reading.melds:
		if meld.is_triplet:
			return false

	# Pair must not be value tiles
	if reading.pairs.size() > 0:
		var pair_type: Tile.TileType = reading.pairs[0].tile_1.tile_type
		if pair_type in [Tile.TileType.HAKU, Tile.TileType.HATSU, Tile.TileType.CHUN]:
			return false
		if _tile_is_wind(pair_type, seat_wind):
			return false
		if _tile_is_wind(pair_type, round_w):
			return false

	return true


func _count_iipeiko(reading: HandData.HandReading) -> int:
	var seq_melds: Array = []
	for meld: HandData.TileMeld in reading.melds:
		if not meld.is_triplet:
			seq_melds.append(meld)

	var pairs_found: int = 0
	var used: Array = []
	for i: int in range(seq_melds.size()):
		if i in used:
			continue
		for j: int in range(i + 1, seq_melds.size()):
			if j in used:
				continue
			if seq_melds[i].equals(seq_melds[j]):
				pairs_found += 1
				used.append(j)
				break

	if pairs_found >= 2:
		return 3  # Ryanpeiko
	return pairs_found  # 0 or 1 (iipeiko)


func players_is_dealer(player_index: int) -> bool:
	return player_index == dealer_index


static func _round_up_hundred(value: int) -> int:
	return int(ceili(float(value) / 100.0)) * 100
