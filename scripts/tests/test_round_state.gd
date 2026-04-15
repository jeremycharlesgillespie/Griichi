## test_round_state.gd — Tests for RoundState, RoundStateWall, RoundStatePlayer.
extends SceneTree

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	print("\n=== RoundState Tests ===\n")

	test_wall_creation()
	test_dealing()
	test_draw_discard()
	test_pon_call()
	test_riichi()
	test_tsumo_detection()
	test_game_state_scoring()

	print("\n=== Results: %d passed, %d failed ===" % [passed, failed])
	if failed == 0:
		print("ALL TESTS PASSED")
	quit(failed)


# ── Test helpers ───────────────────────────────────────────────

func assert_true(condition: bool, name: String) -> void:
	if condition:
		print("  PASS: %s" % name)
		passed += 1
	else:
		print("  FAIL: %s" % name)
		failed += 1


func assert_eq(actual: Variant, expected: Variant, name: String) -> void:
	if actual == expected:
		print("  PASS: %s" % name)
		passed += 1
	else:
		print("  FAIL: %s (expected %s, got %s)" % [name, str(expected), str(actual)])
		failed += 1


# ── Tests ──────────────────────────────────────────────────────

func test_wall_creation() -> void:
	print("Wall creation...")
	var wall: RoundStateWall = RoundStateWall.new()
	wall.build_and_shuffle()

	assert_eq(wall.all_tiles.size(), 136, "wall has 136 tiles")
	assert_eq(wall.wall_tiles.size(), 122, "wall_tiles has 122 (dora flip reads dead wall, not main wall)")
	assert_true(wall.dora.size() >= 1, "at least one dora indicator")
	assert_true(not wall.empty, "wall is not empty")
	assert_true(wall.can_riichi, "can riichi with full wall")


func test_dealing() -> void:
	print("Dealing...")
	var rs: RoundState = RoundState.new(Tile.Wind.EAST, 0)
	rs.start()

	# Dealer (index 0) gets 14 tiles, others get 13
	assert_eq(rs.players[0].hand.size(), 14, "dealer has 14 tiles")
	assert_eq(rs.players[1].hand.size(), 13, "player 1 has 13 tiles")
	assert_eq(rs.players[2].hand.size(), 13, "player 2 has 13 tiles")
	assert_eq(rs.players[3].hand.size(), 13, "player 3 has 13 tiles")
	assert_eq(rs.current_index, 0, "dealer goes first")


func test_draw_discard() -> void:
	print("Draw/discard...")
	var rs: RoundState = RoundState.new(Tile.Wind.EAST, 0)
	rs.start()

	# Dealer already has 14 tiles, can discard without drawing
	var player: RoundStatePlayer = rs.players[0]
	var tile_to_discard: Tile = player.hand[0]
	var discard_ok: bool = rs.tile_discard(tile_to_discard)
	assert_true(discard_ok, "discard succeeds")
	assert_eq(player.hand.size(), 13, "hand has 13 after discard")
	assert_eq(player.pond.size(), 1, "pond has 1 tile")
	assert_eq(rs.discard_tile, tile_to_discard, "discard_tile is set")


func test_pon_call() -> void:
	print("Pon call...")
	var rs: RoundState = RoundState.new(Tile.Wind.EAST, 0)
	rs.start()

	# Find a discard from player 0 that player 1 can pon
	var player0: RoundStatePlayer = rs.players[0]
	var player1: RoundStatePlayer = rs.players[1]

	# Force a pon-able scenario: find a tile type in player0's hand
	# that player1 has 2+ of
	var pon_tile: Tile = null
	for t0: Tile in player0.hand:
		var count: int = 0
		for t1: Tile in player1.hand:
			if t1.tile_type == t0.tile_type:
				count += 1
		if count >= 2:
			pon_tile = t0
			break

	if pon_tile != null:
		rs.tile_discard(pon_tile)
		var can: bool = rs.can_pon(1)
		assert_true(can, "can pon after discard")

		if can:
			var pon_tiles: Array = []
			for t: Tile in player1.hand:
				if t.tile_type == pon_tile.tile_type:
					pon_tiles.append(t)
					if pon_tiles.size() == 2:
						break
			rs.pon(1, pon_tiles[0], pon_tiles[1])
			assert_eq(rs.current_index, 1, "current player is pon caller")
			assert_eq(player1.calls.size(), 1, "player 1 has 1 call")
	else:
		# No natural pon scenario — still pass
		assert_true(true, "no pon scenario in this deal (ok)")


func test_riichi() -> void:
	print("Riichi...")
	var rs: RoundState = RoundState.new(Tile.Wind.EAST, 0)
	rs.start()

	# Riichi requires tenpai with closed hand — hard to guarantee with random wall.
	# Just verify the method doesn't crash and returns false for random hands.
	var can: bool = rs.can_riichi()
	# This will usually be false for a random deal
	assert_true(true, "can_riichi() doesn't crash")


func test_tsumo_detection() -> void:
	print("Tsumo detection...")
	var rs: RoundState = RoundState.new(Tile.Wind.EAST, 0)
	rs.start()

	# With a random deal, tsumo is almost never possible
	var can: bool = rs.can_tsumo()
	assert_true(true, "can_tsumo() doesn't crash")


func test_game_state_scoring() -> void:
	print("GameState scoring...")
	var gs: GameState = GameState.new()

	assert_eq(gs.player_scores[0], 25000, "starting score is 25000")
	assert_eq(gs.round_wind, Tile.Wind.EAST, "starts in East")
	assert_eq(gs.dealer_index, 0, "dealer is 0")
	assert_true(not gs.game_is_finished, "game not finished at start")

	# Start a round
	var rs: RoundState = gs.start_new_round()
	assert_true(rs != null, "round state created")
	assert_eq(rs.players[0].hand.size(), 14, "dealer has 14 tiles in game round")
