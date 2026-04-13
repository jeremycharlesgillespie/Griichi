## test_tile_rules.gd — Automated tests for the core game logic.
## Run headless: godot --headless --script res://scripts/tests/test_tile_rules.gd
extends SceneTree

var passed: int = 0
var failed: int = 0

func assert_true(condition: bool, test_name: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		print("  FAIL: ", test_name)

func assert_eq(actual, expected, test_name: String) -> void:
	if actual == expected:
		passed += 1
	else:
		failed += 1
		print("  FAIL: ", test_name, " (expected ", expected, ", got ", actual, ")")

func make_tile(type: Tile.TileType, tile_id: int = 0) -> Tile:
	return Tile.new(tile_id, type)

func make_hand(types: Array) -> Array:
	var hand: Array = []
	for i: int in range(types.size()):
		hand.append(make_tile(types[i], i))
	return hand

func _initialize() -> void:
	print("=== GRiichi Core Logic Tests ===\n")

	test_tile_basics()
	test_can_pon()
	test_can_chii()
	test_winning_hand()
	test_tenpai()
	test_shanten()
	test_waiting_tiles()
	test_chiitoi()
	test_kokushi()

	print("\n=== Results: ", passed, " passed, ", failed, " failed ===")

	if failed > 0:
		print("SOME TESTS FAILED")
	else:
		print("ALL TESTS PASSED")

	quit(failed)

func test_tile_basics() -> void:
	print("Tile basics...")
	var t: Tile = make_tile(Tile.TileType.MAN1)
	assert_true(t.is_suit_tile(), "MAN1 is suit")
	assert_true(not t.is_honor_tile(), "MAN1 not honor")
	assert_true(t.is_terminal_tile(), "MAN1 is terminal")

	var d: Tile = make_tile(Tile.TileType.CHUN)
	assert_true(d.is_dragon_tile(), "CHUN is dragon")
	assert_true(d.is_honor_tile(), "CHUN is honor")
	assert_true(not d.is_suit_tile(), "CHUN not suit")

	assert_eq(Tile.readable_name(Tile.TileType.SOU3), "3 of Bamboo", "readable name SOU3")
	assert_eq(Tile.compact_name(Tile.TileType.PIN7), "7p", "compact name PIN7")
	assert_eq(Tile.compact_name(Tile.TileType.HAKU), "Wh", "compact name HAKU")

func test_can_pon() -> void:
	print("Can pon...")
	var hand: Array = make_hand([Tile.TileType.MAN1, Tile.TileType.MAN1, Tile.TileType.MAN3])
	var discard: Tile = make_tile(Tile.TileType.MAN1, 99)
	assert_true(TileRules.can_pon(hand, discard), "can pon MAN1 with 2 in hand")

	var discard2: Tile = make_tile(Tile.TileType.MAN3, 99)
	assert_true(not TileRules.can_pon(hand, discard2), "cannot pon MAN3 with 1 in hand")

func test_can_chii() -> void:
	print("Can chii...")
	var hand: Array = make_hand([Tile.TileType.MAN1, Tile.TileType.MAN2, Tile.TileType.SOU5])
	var discard: Tile = make_tile(Tile.TileType.MAN3, 99)
	assert_true(TileRules.can_chii(hand, discard), "can chii 1-2 + discard 3")

	var discard2: Tile = make_tile(Tile.TileType.MAN5, 99)
	assert_true(not TileRules.can_chii(hand, discard2), "cannot chii 1-2 + discard 5")

func test_winning_hand() -> void:
	print("Winning hand...")
	# Simple winning hand: 1-2-3m 4-5-6m 7-8-9m 1-2-3p + pair 5s-5s
	var hand: Array = make_hand([
		Tile.TileType.MAN1, Tile.TileType.MAN2, Tile.TileType.MAN3,
		Tile.TileType.MAN4, Tile.TileType.MAN5, Tile.TileType.MAN6,
		Tile.TileType.MAN7, Tile.TileType.MAN8, Tile.TileType.MAN9,
		Tile.TileType.PIN1, Tile.TileType.PIN2, Tile.TileType.PIN3,
		Tile.TileType.SOU5, Tile.TileType.SOU5
	])
	assert_true(TileRules.winning_hand(hand, []), "valid 14-tile winning hand")

	# Not a winning hand: random tiles
	var bad_hand: Array = make_hand([
		Tile.TileType.MAN1, Tile.TileType.MAN3, Tile.TileType.MAN5,
		Tile.TileType.PIN2, Tile.TileType.PIN4, Tile.TileType.PIN6,
		Tile.TileType.SOU1, Tile.TileType.SOU3, Tile.TileType.SOU5,
		Tile.TileType.TON, Tile.TileType.NAN, Tile.TileType.SHAA,
		Tile.TileType.PEI, Tile.TileType.HAKU
	])
	assert_true(not TileRules.winning_hand(bad_hand, []), "invalid hand not winning")

func test_tenpai() -> void:
	print("Tenpai...")
	# 13-tile hand waiting for MAN3 to complete 1-2-3m
	var hand: Array = make_hand([
		Tile.TileType.MAN1, Tile.TileType.MAN2,
		Tile.TileType.MAN4, Tile.TileType.MAN5, Tile.TileType.MAN6,
		Tile.TileType.MAN7, Tile.TileType.MAN8, Tile.TileType.MAN9,
		Tile.TileType.PIN1, Tile.TileType.PIN2, Tile.TileType.PIN3,
		Tile.TileType.SOU5, Tile.TileType.SOU5
	])
	assert_true(TileRules.in_tenpai(hand, []), "tenpai hand waiting for 3m")

func test_shanten() -> void:
	print("Shanten...")
	# Tenpai hand → shanten 0
	var tenpai: Array = make_hand([
		Tile.TileType.MAN1, Tile.TileType.MAN2,
		Tile.TileType.MAN4, Tile.TileType.MAN5, Tile.TileType.MAN6,
		Tile.TileType.MAN7, Tile.TileType.MAN8, Tile.TileType.MAN9,
		Tile.TileType.PIN1, Tile.TileType.PIN2, Tile.TileType.PIN3,
		Tile.TileType.SOU5, Tile.TileType.SOU5
	])
	assert_eq(TileRules.get_shanten(tenpai, []), 0, "tenpai = shanten 0")

func test_waiting_tiles() -> void:
	print("Waiting tiles...")
	var hand: Array = make_hand([
		Tile.TileType.MAN1, Tile.TileType.MAN2,
		Tile.TileType.MAN4, Tile.TileType.MAN5, Tile.TileType.MAN6,
		Tile.TileType.MAN7, Tile.TileType.MAN8, Tile.TileType.MAN9,
		Tile.TileType.PIN1, Tile.TileType.PIN2, Tile.TileType.PIN3,
		Tile.TileType.SOU5, Tile.TileType.SOU5
	])
	var waits: Array = TileRules.waiting_tiles(hand, [])
	assert_true(waits.size() > 0, "has waiting tiles")

	var wait_types: Array = []
	for w: Tile in waits:
		wait_types.append(int(w.tile_type))
	assert_true(int(Tile.TileType.MAN3) in wait_types, "waiting on MAN3")

func test_chiitoi() -> void:
	print("Chiitoi...")
	var hand: Array = make_hand([
		Tile.TileType.MAN1, Tile.TileType.MAN1,
		Tile.TileType.MAN3, Tile.TileType.MAN3,
		Tile.TileType.PIN5, Tile.TileType.PIN5,
		Tile.TileType.PIN7, Tile.TileType.PIN7,
		Tile.TileType.SOU2, Tile.TileType.SOU2,
		Tile.TileType.TON, Tile.TileType.TON,
		Tile.TileType.CHUN, Tile.TileType.CHUN
	])
	assert_true(TileRules.winning_hand(hand, []), "chiitoi is winning hand")

func test_kokushi() -> void:
	print("Kokushi...")
	var hand: Array = make_hand([
		Tile.TileType.MAN1, Tile.TileType.MAN9,
		Tile.TileType.PIN1, Tile.TileType.PIN9,
		Tile.TileType.SOU1, Tile.TileType.SOU9,
		Tile.TileType.TON, Tile.TileType.NAN, Tile.TileType.SHAA, Tile.TileType.PEI,
		Tile.TileType.HAKU, Tile.TileType.HATSU, Tile.TileType.CHUN,
		Tile.TileType.MAN1  # duplicate
	])
	assert_true(TileRules.winning_hand(hand, []), "kokushi is winning hand")
