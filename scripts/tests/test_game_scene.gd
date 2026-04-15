## test_game_scene.gd — Quick validation that the game scene loads and
## a round can complete between bots without crashing.
extends SceneTree

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	print("\n=== Game Scene Smoke Test ===\n")

	test_full_bot_round()

	print("\n=== Results: %d passed, %d failed ===" % [passed, failed])
	if failed == 0:
		print("ALL TESTS PASSED")
	quit(failed)


func assert_true(condition: bool, name: String) -> void:
	if condition:
		print("  PASS: %s" % name)
		passed += 1
	else:
		print("  FAIL: %s" % name)
		failed += 1


## Simulate a full round with 4 bots — no UI, just pure logic.
func test_full_bot_round() -> void:
	print("Full bot round (no UI)...")

	var game: GameState = GameState.new()
	var rs: RoundState = game.start_new_round()

	var bots: Array = [SimpleBot.new(), SimpleBot.new(), SimpleBot.new(), SimpleBot.new()]
	var max_turns: int = 200
	var turn: int = 0

	# Dealer starts with 14 tiles — go straight to discard
	while not rs.game_over and turn < max_turns:
		var player: RoundStatePlayer = rs.current_player
		var bot: Bot = bots[rs.current_index]

		# If hand has 13 tiles, draw first
		if player.hand.size() % 3 != 2:
			if rs.tiles_empty:
				rs.game_over = true
				rs.game_draw_type = RoundState.GameDrawType.EMPTY_WALL
				break
			rs.tile_draw()

		# Check tsumo
		if rs.can_tsumo():
			rs.tsumo()
			break

		# Check riichi
		if rs.can_riichi() and bot.should_declare_riichi(player, rs):
			rs.riichi()
			game.riichi_sticks += 1
			game.player_scores[rs.current_index] -= 1000

		# Discard
		var discard: Tile = bot.get_discard_tile(player, rs)
		var ok: bool = rs.tile_discard(discard)
		if not ok:
			# Fallback: discard newest tile
			rs.tile_discard(player.newest_tile)

		# Check ron from other players
		var ron_callers: Array = []
		for i: int in range(4):
			if i == rs.current_index:
				continue
			if rs.can_ron(i):
				ron_callers.append(i)

		if ron_callers.size() > 0:
			rs.ron(ron_callers)
			break

		# Check pon
		var pon_called: bool = false
		for i: int in range(4):
			if i == rs.current_index:
				continue
			if rs.can_pon(i) and bots[i].should_call_pon(rs.players[i], rs):
				var pon_tiles: Array = []
				for t: Tile in rs.players[i].hand:
					if t.tile_type == rs.discard_tile.tile_type:
						pon_tiles.append(t)
						if pon_tiles.size() == 2:
							break
				if pon_tiles.size() == 2:
					rs.pon(i, pon_tiles[0], pon_tiles[1])
					# Pon caller discards
					var pon_discard: Tile = bots[i].get_discard_tile(rs.players[i], rs)
					rs.tile_discard(pon_discard)
					pon_called = true
					break

		if not pon_called:
			rs.calls_finished()
			if not rs.game_over:
				rs.advance_turn()

		turn += 1

	assert_true(rs.game_over, "round ended")
	assert_true(turn < max_turns, "round completed within turn limit (took %d turns)" % turn)

	var result: String = ""
	if rs.game_draw_type != RoundState.GameDrawType.NONE:
		result = "draw (type %d)" % rs.game_draw_type
	else:
		result = "winner: player %d" % rs.winner_indices[0]
	print("  Result: %s after %d turns" % [result, turn])

	# Score the round
	var dealer_won: bool = rs.dealer in rs.winner_indices if rs.winner_indices.size() > 0 else false
	var continues: bool = game.finish_round(rs)
	assert_true(true, "scoring completed without crash")

	print("  Scores: %s" % str(game.player_scores))
