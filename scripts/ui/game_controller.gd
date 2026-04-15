## game_controller.gd — Main game scene controller.
##
## Orchestrates the draw/discard cycle between human player and bots.
## Manages tile 3D rendering, input handling, HUD updates, and
## call/win decision flow.
extends Node3D


# ── Constants ──────────────────────────────────────────────────

const TILE_WIDTH: float = 0.032
const TILE_HEIGHT: float = 0.042
const TILE_DEPTH: float = 0.022
const TILE_SPACING: float = 0.034
const HAND_Y: float = 0.012          # Tiles sit on the table
const HAND_Z: float = 0.32           # Player hand distance from center
const OPPONENT_HAND_Z: float = 0.44  # Opponent hands distance
const POND_START_Z: float = 0.13     # Pond starts outside center (in front of player)
const POND_TILE_SPACING: float = 0.035
const POND_ROW_SPACING: float = 0.047
const CALL_MELD_X: float = 0.32      # Open melds shown to right of hand
const DEAD_WALL_X: float = 0.0       # Dead wall centered at top of table
const DEAD_WALL_Z: float = -0.62     # In front of "across" player area
const DEAD_WALL_TILE_SPACING: float = 0.035
const BOT_THINK_DELAY: float = 0.4   # Seconds bots "think"

const PLAYER_INDEX: int = 0          # Human is always player 0

# Colors for tile faces by suit
const SUIT_COLORS: Dictionary = {
	"man": Color(0.9, 0.2, 0.2),     # Red
	"pin": Color(0.2, 0.5, 0.9),     # Blue
	"sou": Color(0.2, 0.8, 0.3),     # Green
	"honor": Color(0.15, 0.15, 0.15) # Dark
}


# ── State ──────────────────────────────────────────────────────

var game_state: GameState = null
var round_state: RoundState = null
var bots: Array = []                  # Array of Bot (indices 1-3)

var hand_tile_nodes: Array = []       # Array of Node3D for player hand
var opponent_hand_nodes: Array = []   # Array[3] of Array of Node3D per opponent
var pond_tile_nodes: Array = []       # Array[4] of Array of Node3D per player
var meld_tile_nodes: Array = []       # Array[4] of Array of Node3D per player (called melds)
var dora_tile_nodes: Array = []       # Dora indicator tiles
var wind_label_nodes: Array = []      # Array[4] of Label3D for seat winds
var riichi_stick_nodes: Array = []    # Array[4] of Node3D for riichi sticks
var hovered_tile_index: int = -1
var selected_tile: Tile = null

var waiting_for_player_discard: bool = false
var waiting_for_player_call: bool = false
var available_calls: Dictionary = {}   # {pon: bool, chii: Array, ron: bool, kan: bool}

enum Phase { IDLE, PLAYER_DRAW, PLAYER_DISCARD, PLAYER_CALL_DECISION,
			 BOT_TURN, ROUND_OVER, GAME_OVER }
var current_phase: int = Phase.IDLE

@onready var camera: Camera3D = $Camera3D
@onready var table_mesh: MeshInstance3D = $Table
@onready var hud: Control = $HUD
@onready var bot_timer: Timer = $BotTimer


# ── Initialization ─────────────────────────────────────────────

func _ready() -> void:
	# Initialize bots for positions 1, 2, 3
	bots = [SimpleBot.new(), SimpleBot.new(), SimpleBot.new()]

	# Initialize per-player arrays
	for _i: int in range(4):
		pond_tile_nodes.append([])
		meld_tile_nodes.append([])
		riichi_stick_nodes.append(null)
		wind_label_nodes.append(null)

	_create_seat_wind_labels()

	# Start the game
	game_state = GameState.new()
	_start_new_round()


func _start_new_round() -> void:
	_clear_all_tiles()
	round_state = game_state.start_new_round()
	_render_player_hand()
	_render_opponent_hands()
	_update_all_ponds()
	_update_all_melds()
	_render_dora_indicators()
	_update_seat_wind_labels()
	_update_hud()

	# Dealer goes first — if dealer is player, wait for draw action
	if round_state.current_index == PLAYER_INDEX:
		_start_player_turn()
	else:
		_start_bot_turn()


# ── Player turn flow ──────────────────────────────────────────

func _start_player_turn() -> void:
	current_phase = Phase.PLAYER_DRAW

	# Draw a tile (skip if already at 14 — dealer's first turn)
	var player: RoundStatePlayer = round_state.players[PLAYER_INDEX]
	if player.hand.size() % 3 != 2:
		var drawn: Tile = round_state.tile_draw()
	_render_player_hand()
	_update_hud()

	# Check for tsumo
	if round_state.can_tsumo():
		_show_call_buttons({&"tsumo": true})
		waiting_for_player_call = true
		return

	# Check for kan
	var has_kan: bool = round_state.can_closed_kan() or round_state.can_late_kan()

	# Check for riichi
	var has_riichi: bool = round_state.can_riichi()

	if has_kan or has_riichi:
		var calls: Dictionary = {}
		if has_kan:
			calls[&"kan"] = true
		if has_riichi:
			calls[&"riichi"] = true
		_show_call_buttons(calls)
		# Player can also just discard, so don't block

	current_phase = Phase.PLAYER_DISCARD
	waiting_for_player_discard = true


func _player_discard(tile: Tile) -> void:
	waiting_for_player_discard = false
	_hide_call_buttons()

	if not round_state.tile_discard(tile):
		# Invalid discard — let player try again
		waiting_for_player_discard = true
		return

	_render_player_hand()
	_add_pond_tile(PLAYER_INDEX, tile)
	_update_hud()

	# Check if any bot wants to call
	_check_bot_calls_on_discard()


func _check_bot_calls_on_discard() -> void:
	# Priority: ron > pon/kan > chii
	var ron_callers: Array = []
	for i: int in range(1, 4):
		if round_state.can_ron(i):
			ron_callers.append(i)

	if ron_callers.size() > 0:
		# Bots always call ron
		round_state.ron(ron_callers)
		_end_round()
		return

	# Check pon/kan (any bot)
	for i: int in range(1, 4):
		var bot: Bot = bots[i - 1]
		if round_state.can_open_kan(i):
			# Bots do open kan if they'd pon
			if bot.should_call_pon(round_state.players[i], round_state):
				_do_bot_open_kan(i)
				return

		if round_state.can_pon(i):
			if bot.should_call_pon(round_state.players[i], round_state):
				_do_bot_pon(i)
				return

	# Check chii (only next player)
	var next_index: int = (round_state.current_index + 1) % 4
	if next_index != PLAYER_INDEX and round_state.can_chii(next_index):
		var bot: Bot = bots[next_index - 1]
		var chii_tiles: Array = bot.get_chii_tiles(round_state.players[next_index], round_state)
		if chii_tiles.size() == 2:
			_do_bot_chii(next_index, chii_tiles[0], chii_tiles[1])
			return

	# No calls — advance turn
	round_state.calls_finished()
	if round_state.game_over:
		_end_round()
		return
	round_state.advance_turn()
	_next_turn()


# ── Bot turn flow ──────────────────────────────────────────────

func _start_bot_turn() -> void:
	current_phase = Phase.BOT_TURN
	bot_timer.start(BOT_THINK_DELAY)
	await bot_timer.timeout
	_do_bot_turn()


func _do_bot_turn() -> void:
	if round_state.game_over:
		_end_round()
		return

	var bot_index: int = round_state.current_index
	var bot: Bot = bots[bot_index - 1]
	var player: RoundStatePlayer = round_state.players[bot_index]

	# Draw (skip if already at 14 — dealer's first turn)
	if player.hand.size() % 3 != 2:
		var drawn: Tile = round_state.tile_draw()

	# Check tsumo
	if round_state.can_tsumo():
		if bot.should_tsumo(player, round_state):
			round_state.tsumo()
			_end_round()
			return

	# Check riichi
	if round_state.can_riichi():
		if bot.should_declare_riichi(player, round_state):
			round_state.riichi()
			game_state.riichi_sticks += 1
			game_state.player_scores[bot_index] -= 1000

	# Check closed kan
	if round_state.can_closed_kan():
		var kan_types: Array = player.get_closed_kan_types()
		if kan_types.size() > 0:
			round_state.closed_kan(kan_types[0])
			# After kan, bot gets another draw — recurse
			_update_all_ponds()
			_do_bot_turn()
			return

	# Discard
	var discard: Tile = bot.get_discard_tile(player, round_state)
	round_state.tile_discard(discard)
	_add_pond_tile(bot_index, discard)
	_render_opponent_hands()
	_update_hud()

	# Check if player can call on this discard
	_check_player_calls_on_discard()


func _check_player_calls_on_discard() -> void:
	var calls: Dictionary = {}
	var dt: Tile = round_state.discard_tile
	var player: RoundStatePlayer = round_state.players[PLAYER_INDEX]

	if round_state.can_ron(PLAYER_INDEX):
		calls[&"ron"] = "Ron on " + Tile.compact_name(dt.tile_type)

	if round_state.can_pon(PLAYER_INDEX):
		calls[&"pon"] = "Pon " + Tile.compact_name(dt.tile_type)

	if round_state.can_open_kan(PLAYER_INDEX):
		calls[&"kan"] = "Kan " + Tile.compact_name(dt.tile_type)

	if round_state.can_chii(PLAYER_INDEX):
		var groups: Array = TileRules.get_chii_groups(player.hand, dt)
		if groups.size() == 1:
			var g: Array = groups[0]
			calls[&"chii"] = "Chii " + Tile.compact_name(g[0].tile_type) + "-" \
				+ Tile.compact_name(dt.tile_type) + "-" + Tile.compact_name(g[1].tile_type)
		else:
			calls[&"chii"] = "Chii (" + str(groups.size()) + " ways)"

	if calls.size() > 0:
		available_calls = calls
		_show_call_buttons(calls)
		current_phase = Phase.PLAYER_CALL_DECISION
		waiting_for_player_call = true
		return

	# No calls available — check bot calls on each other
	_check_bot_calls_on_bot_discard()


func _check_bot_calls_on_bot_discard() -> void:
	# Check if other bots want to call
	var discarder: int = round_state.current_index

	var ron_callers: Array = []
	for i: int in range(1, 4):
		if i == discarder:
			continue
		if round_state.can_ron(i):
			ron_callers.append(i)

	if ron_callers.size() > 0:
		round_state.ron(ron_callers)
		_end_round()
		return

	for i: int in range(1, 4):
		if i == discarder:
			continue
		var bot: Bot = bots[i - 1]

		if round_state.can_pon(i) and bot.should_call_pon(round_state.players[i], round_state):
			_do_bot_pon(i)
			return

	var next_index: int = (discarder + 1) % 4
	if next_index != PLAYER_INDEX and next_index != discarder and round_state.can_chii(next_index):
		var bot: Bot = bots[next_index - 1]
		var chii_tiles: Array = bot.get_chii_tiles(round_state.players[next_index], round_state)
		if chii_tiles.size() == 2:
			_do_bot_chii(next_index, chii_tiles[0], chii_tiles[1])
			return

	# No calls — advance
	round_state.calls_finished()
	if round_state.game_over:
		_end_round()
		return
	round_state.advance_turn()
	_next_turn()


# ── Bot call execution ─────────────────────────────────────────

func _do_bot_pon(bot_index: int) -> void:
	var player: RoundStatePlayer = round_state.players[bot_index]
	var dt: Tile = round_state.discard_tile
	var pon_tiles: Array = []
	for tile: Tile in player.hand:
		if tile.tile_type == dt.tile_type:
			pon_tiles.append(tile)
			if pon_tiles.size() == 2:
				break

	round_state.pon(bot_index, pon_tiles[0], pon_tiles[1])
	_update_all_ponds()

	# Bot must now discard
	var bot: Bot = bots[bot_index - 1]
	var discard: Tile = bot.get_discard_tile(round_state.players[bot_index], round_state)
	round_state.tile_discard(discard)
	_add_pond_tile(bot_index, discard)
	_update_hud()
	_render_player_hand()

	# Check calls on this new discard
	_check_player_calls_on_discard()


func _do_bot_chii(bot_index: int, t1: Tile, t2: Tile) -> void:
	round_state.chii(bot_index, t1, t2)
	_update_all_ponds()

	var bot: Bot = bots[bot_index - 1]
	var discard: Tile = bot.get_discard_tile(round_state.players[bot_index], round_state)
	round_state.tile_discard(discard)
	_add_pond_tile(bot_index, discard)
	_update_hud()
	_render_player_hand()

	_check_player_calls_on_discard()


func _do_bot_open_kan(bot_index: int) -> void:
	var player: RoundStatePlayer = round_state.players[bot_index]
	var dt: Tile = round_state.discard_tile
	var kan_tiles: Array = []
	for tile: Tile in player.hand:
		if tile.tile_type == dt.tile_type:
			kan_tiles.append(tile)
			if kan_tiles.size() == 3:
				break

	round_state.open_kan(bot_index, kan_tiles[0], kan_tiles[1], kan_tiles[2])
	_update_all_ponds()

	# After kan, bot draws from dead wall and continues turn
	_do_bot_turn()


# ── Player call execution ─────────────────────────────────────

func _on_call_button_pressed(call_type: String) -> void:
	waiting_for_player_call = false
	_hide_call_buttons()

	match call_type:
		"tsumo":
			round_state.tsumo()
			_end_round()

		"ron":
			round_state.ron([PLAYER_INDEX])
			_end_round()

		"pon":
			_do_player_pon()

		"chii":
			_do_player_chii()

		"kan":
			_do_player_kan()

		"riichi":
			round_state.riichi()
			game_state.riichi_sticks += 1
			game_state.player_scores[PLAYER_INDEX] -= 1000
			_update_hud()
			# Player still needs to discard

		"skip":
			_on_player_skip_call()


func _on_player_skip_call() -> void:
	available_calls.clear()

	if current_phase == Phase.PLAYER_CALL_DECISION:
		# Was waiting for call on bot's discard — check other bots
		_check_bot_calls_on_bot_discard()
	elif current_phase == Phase.PLAYER_DRAW:
		# Skip tsumo/kan/riichi — go to discard
		current_phase = Phase.PLAYER_DISCARD
		waiting_for_player_discard = true


func _do_player_pon() -> void:
	var player: RoundStatePlayer = round_state.players[PLAYER_INDEX]
	var dt: Tile = round_state.discard_tile
	var pon_tiles: Array = []
	for tile: Tile in player.hand:
		if tile.tile_type == dt.tile_type:
			pon_tiles.append(tile)
			if pon_tiles.size() == 2:
				break

	round_state.pon(PLAYER_INDEX, pon_tiles[0], pon_tiles[1])
	_render_player_hand()
	_update_all_ponds()
	_update_hud()

	# Player must now discard
	current_phase = Phase.PLAYER_DISCARD
	waiting_for_player_discard = true


func _do_player_chii() -> void:
	var player: RoundStatePlayer = round_state.players[PLAYER_INDEX]
	var groups: Array = TileRules.get_chii_groups(player.hand, round_state.discard_tile)
	if groups.size() == 0:
		return

	# Use first valid group
	var group: Array = groups[0]
	round_state.chii(PLAYER_INDEX, group[0], group[1])
	_render_player_hand()
	_update_all_ponds()
	_update_hud()

	current_phase = Phase.PLAYER_DISCARD
	waiting_for_player_discard = true


func _do_player_kan() -> void:
	# Check closed kan first, then late kan
	if round_state.can_closed_kan():
		var types: Array = round_state.players[PLAYER_INDEX].get_closed_kan_types()
		if types.size() > 0:
			round_state.closed_kan(types[0])
			_render_player_hand()
			_update_hud()
			# After kan, draw from dead wall
			_start_player_turn()
			return

	if round_state.can_late_kan():
		# Find a tile that matches an existing pon
		var player: RoundStatePlayer = round_state.players[PLAYER_INDEX]
		for tile: Tile in player.hand:
			for call: HandData.RoundStateCall in player.calls:
				if call.call_type == HandData.RoundStateCall.CallType.PON \
					and call.tiles[0].tile_type == tile.tile_type:
					round_state.late_kan(tile)
					_render_player_hand()
					_update_hud()
					_start_player_turn()
					return

	if round_state.can_open_kan(PLAYER_INDEX):
		var player: RoundStatePlayer = round_state.players[PLAYER_INDEX]
		var dt: Tile = round_state.discard_tile
		var kan_tiles: Array = []
		for tile: Tile in player.hand:
			if tile.tile_type == dt.tile_type:
				kan_tiles.append(tile)
				if kan_tiles.size() == 3:
					break
		round_state.open_kan(PLAYER_INDEX, kan_tiles[0], kan_tiles[1], kan_tiles[2])
		_render_player_hand()
		_update_all_ponds()
		_update_hud()
		_start_player_turn()


# ── Turn dispatch ──────────────────────────────────────────────

func _next_turn() -> void:
	if round_state.game_over:
		_end_round()
		return

	if round_state.current_index == PLAYER_INDEX:
		_start_player_turn()
	else:
		_start_bot_turn()


# ── Round end ──────────────────────────────────────────────────

func _end_round() -> void:
	current_phase = Phase.ROUND_OVER
	waiting_for_player_discard = false
	waiting_for_player_call = false
	_hide_call_buttons()

	# Determine what happened
	var result_text: String = ""

	if round_state.game_draw_type != RoundState.GameDrawType.NONE:
		result_text = _get_draw_text(round_state.game_draw_type)
	else:
		var winner_index: int = round_state.winner_indices[0]
		var winner_name: String = game_state.player_names[winner_index]

		if winner_index == PLAYER_INDEX:
			result_text = "You win!"
		else:
			result_text = winner_name + " wins!"

	# Score the round
	var dealer_won: bool = round_state.dealer in round_state.winner_indices
	var do_renchan: bool = dealer_won
	if round_state.game_draw_type == RoundState.GameDrawType.EMPTY_WALL:
		var tenpai: Array = round_state.get_tenpai_players()
		do_renchan = round_state.dealer in tenpai

	var continues: bool = game_state.finish_round(round_state)

	_update_hud()
	hud.show_round_result(result_text, game_state.player_scores)

	if not continues:
		current_phase = Phase.GAME_OVER
		hud.show_game_over(game_state.player_scores)


func _get_draw_text(draw_type: int) -> String:
	match draw_type:
		RoundState.GameDrawType.EMPTY_WALL: return "Exhaustive draw"
		RoundState.GameDrawType.FOUR_KANS:  return "Draw: Four kans"
		RoundState.GameDrawType.FOUR_RIICHI: return "Draw: Four riichi"
		RoundState.GameDrawType.FOUR_WINDS:  return "Draw: Four winds"
	return "Draw"


func _on_next_round_pressed() -> void:
	if current_phase == Phase.GAME_OVER:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	var dealer_won: bool = false
	if round_state.winner_indices.size() > 0:
		dealer_won = round_state.dealer in round_state.winner_indices

	game_state.advance_round(dealer_won)
	_start_new_round()


# ── Input handling ─────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# Always track hover for tooltip (even during bot turns — visual feedback only)
	if event is InputEventMouseMotion:
		_update_tile_hover(event.position)

	if not waiting_for_player_discard:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_try_click_tile(event.position)


func _update_tile_hover(screen_pos: Vector2) -> void:
	var new_hover: int = _get_tile_at_screen_pos(screen_pos)

	# Update tooltip
	var player: RoundStatePlayer = round_state.players[PLAYER_INDEX] if round_state != null else null
	if new_hover >= 0 and player != null and new_hover < player.hand.size():
		var tile: Tile = player.hand[new_hover]
		var text: String = Tile.readable_name(tile.tile_type)
		if tile.dora:
			text += "  (dora)"
		if hud != null and hud.has_method("show_tile_tooltip"):
			hud.show_tile_tooltip(text, screen_pos)
	else:
		if hud != null and hud.has_method("hide_tile_tooltip"):
			hud.hide_tile_tooltip()

	if new_hover == hovered_tile_index:
		return

	# Un-hover old
	if hovered_tile_index >= 0 and hovered_tile_index < hand_tile_nodes.size():
		var old_node: Node3D = hand_tile_nodes[hovered_tile_index]
		old_node.position.y = HAND_Y

	hovered_tile_index = new_hover

	# Hover new
	if hovered_tile_index >= 0 and hovered_tile_index < hand_tile_nodes.size():
		var new_node: Node3D = hand_tile_nodes[hovered_tile_index]
		new_node.position.y = HAND_Y + 0.008


func _try_click_tile(screen_pos: Vector2) -> void:
	var tile_index: int = _get_tile_at_screen_pos(screen_pos)
	if tile_index < 0:
		return

	var player: RoundStatePlayer = round_state.players[PLAYER_INDEX]
	if tile_index >= player.hand.size():
		return

	var tile: Tile = player.hand[tile_index]
	if player.can_discard(tile):
		_player_discard(tile)


func _get_tile_at_screen_pos(screen_pos: Vector2) -> int:
	if camera == null:
		return -1

	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)

	# Intersect with tile plane (y = HAND_Y + TILE_HEIGHT/2)
	var plane_y: float = HAND_Y + TILE_HEIGHT * 0.5
	if abs(dir.y) < 0.001:
		return -1

	var t: float = (plane_y - from.y) / dir.y
	if t < 0:
		return -1

	var hit: Vector3 = from + dir * t

	# Check if hit is in tile range
	var hand_size: int = hand_tile_nodes.size()
	if hand_size == 0:
		return -1

	var total_width: float = hand_size * TILE_SPACING
	var start_x: float = -total_width / 2.0

	# Check z range
	if abs(hit.z - HAND_Z) > TILE_DEPTH:
		return -1

	var relative_x: float = hit.x - start_x
	if relative_x < 0 or relative_x > total_width:
		return -1

	var index: int = int(relative_x / TILE_SPACING)
	if index >= hand_size:
		index = hand_size - 1

	return index


# ── Tile rendering ─────────────────────────────────────────────

func _render_player_hand() -> void:
	_shanten_dirty = true

	# Clear old hand tiles
	for node: Node3D in hand_tile_nodes:
		node.queue_free()
	hand_tile_nodes.clear()

	var player: RoundStatePlayer = round_state.players[PLAYER_INDEX]
	var hand: Array = player.hand
	var total_width: float = hand.size() * TILE_SPACING
	var start_x: float = -total_width / 2.0

	for i: int in range(hand.size()):
		var tile: Tile = hand[i]
		var tile_node: Node3D = _create_tile_mesh(tile, true)
		var x: float = start_x + i * TILE_SPACING + TILE_WIDTH / 2.0
		tile_node.position = Vector3(x, HAND_Y, HAND_Z)
		add_child(tile_node)
		hand_tile_nodes.append(tile_node)


func _render_opponent_hands() -> void:
	# Clear old opponent tiles
	for opp_nodes: Array in opponent_hand_nodes:
		for node: Node3D in opp_nodes:
			if is_instance_valid(node):
				node.queue_free()
	opponent_hand_nodes.clear()

	for player_index: int in [1, 2, 3]:
		var nodes: Array = []
		var player: RoundStatePlayer = round_state.players[player_index]
		var tile_count: int = player.hand.size()
		var total_width: float = tile_count * TILE_SPACING
		var start_offset: float = -total_width / 2.0

		for i: int in range(tile_count):
			var tile_node: Node3D = _create_tile_mesh(null, false)
			var local_x: float = start_offset + i * TILE_SPACING + TILE_WIDTH / 2.0

			match player_index:
				1:  # Right side — tiles run along Z axis
					tile_node.position = Vector3(-OPPONENT_HAND_Z, HAND_Y, local_x)
					tile_node.rotation.y = PI / 2.0
				2:  # Across — tiles run along X axis, facing away
					tile_node.position = Vector3(-local_x, HAND_Y, -OPPONENT_HAND_Z)
					tile_node.rotation.y = PI
				3:  # Left side — tiles run along Z axis
					tile_node.position = Vector3(OPPONENT_HAND_Z, HAND_Y, -local_x)
					tile_node.rotation.y = -PI / 2.0

			add_child(tile_node)
			nodes.append(tile_node)

		opponent_hand_nodes.append(nodes)


func _add_pond_tile(player_index: int, tile: Tile) -> void:
	# All pond tiles are face-up so everyone can see discards
	var tile_node: Node3D = _create_pond_tile_mesh(tile)

	var pond_count: int = pond_tile_nodes[player_index].size()
	var row: int = pond_count / 6
	var col: int = pond_count % 6

	var pos: Vector3 = _get_pond_position(player_index, row, col)
	tile_node.position = pos

	# Rotate pond tile so it faces the player who discarded it
	match player_index:
		1: tile_node.rotation.y = -PI / 2.0   # Right player: tiles face right
		2: tile_node.rotation.y = PI          # Across: tiles face away
		3: tile_node.rotation.y = PI / 2.0    # Left player: tiles face left

	add_child(tile_node)
	pond_tile_nodes[player_index].append(tile_node)


func _get_pond_position(player_index: int, row: int, col: int) -> Vector3:
	# col 0..5 centered on player's side, row stacks outward from center
	var local_x: float = (col - 2.5) * POND_TILE_SPACING
	var local_z: float = POND_START_Z + row * POND_ROW_SPACING
	var y: float = 0.011

	match player_index:
		0:  return Vector3(local_x, y, local_z)       # Player (bottom, Z+)
		1:  return Vector3(local_z, y, -local_x)      # Right player (X+)
		2:  return Vector3(-local_x, y, -local_z)     # Across (Z-)
		3:  return Vector3(-local_z, y, local_x)      # Left player (X-)

	return Vector3.ZERO


# ── Called melds display ──────────────────────────────────────

func _update_all_melds() -> void:
	for nodes: Array in meld_tile_nodes:
		for n: Node3D in nodes:
			if is_instance_valid(n):
				n.queue_free()
		nodes.clear()

	for i: int in range(4):
		_render_melds_for_player(i)


func _render_melds_for_player(player_index: int) -> void:
	var player: RoundStatePlayer = round_state.players[player_index]
	var meld_offset_x: float = 0.0  # Cumulative offset from start position

	for call: HandData.RoundStateCall in player.calls:
		var meld_start_x: float = meld_offset_x
		for i: int in range(call.tiles.size()):
			var tile: Tile = call.tiles[i]
			var tile_node: Node3D = _create_pond_tile_mesh(tile)

			var local_x: float = meld_offset_x + TILE_WIDTH / 2.0
			var pos: Vector3 = _get_meld_position(player_index, local_x)
			tile_node.position = pos

			# Apply player rotation
			match player_index:
				1: tile_node.rotation.y = -PI / 2.0
				2: tile_node.rotation.y = PI
				3: tile_node.rotation.y = PI / 2.0

			add_child(tile_node)
			meld_tile_nodes[player_index].append(tile_node)
			meld_offset_x += TILE_WIDTH + 0.003

		meld_offset_x += 0.01  # Gap between melds


func _get_meld_position(player_index: int, local_x: float) -> Vector3:
	# Melds are placed at the right side of the player's area
	var local_z: float = CALL_MELD_X  # Distance from center (opposite of near pond)
	var offset_x: float = CALL_MELD_X - 0.05 - local_x  # Right-justified

	match player_index:
		0:  return Vector3(offset_x, 0.011, CALL_MELD_X + 0.05)
		1:  return Vector3(CALL_MELD_X + 0.05, 0.011, -offset_x)
		2:  return Vector3(-offset_x, 0.011, -(CALL_MELD_X + 0.05))
		3:  return Vector3(-(CALL_MELD_X + 0.05), 0.011, offset_x)

	return Vector3.ZERO


# ── Dead wall + dora indicator display ────────────────────────

## Renders the dead wall (7 stacks of 2 = 14 tiles) with dora indicators
## face-up. Face-down stacks represent rinshanpai and unrevealed dora.
func _render_dora_indicators() -> void:
	# Clear old dora/dead-wall tiles
	for node: Node3D in dora_tile_nodes:
		if is_instance_valid(node):
			node.queue_free()
	dora_tile_nodes.clear()

	# Dead wall: 7 stacks of 2 tiles, laid along the top edge of the table
	# Top layer: positions 0-6 (kan dora flip revealed tiles here)
	# Bottom layer: ura-dora (hidden), rinshanpai (replacement draws)
	var revealed_count: int = round_state.wall.dora.size()

	for i: int in range(7):
		# Bottom tile of each stack — face down (ura-dora or rinshan replacement)
		var bottom: Node3D = _create_flat_tile_back()
		bottom.position = Vector3(
			DEAD_WALL_X + (i - 3) * DEAD_WALL_TILE_SPACING,
			0.011,
			DEAD_WALL_Z
		)
		add_child(bottom)
		dora_tile_nodes.append(bottom)

		# Top tile — face up if it's a revealed dora indicator (position 2 is first dora)
		# In real mahjong the dora indicator is the 3rd stack from the right-end
		var dora_slot: int = 2  # 3rd position from one end
		var is_revealed_dora: bool = (i - dora_slot) >= 0 and (i - dora_slot) < revealed_count

		if is_revealed_dora:
			var dora_tile: Tile = round_state.wall.dora[i - dora_slot]
			var top: Node3D = _create_pond_tile_mesh(dora_tile)
			top.position = Vector3(
				DEAD_WALL_X + (i - 3) * DEAD_WALL_TILE_SPACING,
				0.011 + TILE_DEPTH + 0.002,
				DEAD_WALL_Z
			)
			add_child(top)
			dora_tile_nodes.append(top)
		else:
			var top: Node3D = _create_flat_tile_back()
			top.position = Vector3(
				DEAD_WALL_X + (i - 3) * DEAD_WALL_TILE_SPACING,
				0.011 + TILE_DEPTH + 0.002,
				DEAD_WALL_Z
			)
			add_child(top)
			dora_tile_nodes.append(top)


## Create a face-down tile laid flat (for wall visualization).
func _create_flat_tile_back() -> Node3D:
	_ensure_tile_meshes()
	var root: Node3D = Node3D.new()

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _back_flat_mesh
	mi.position.y = TILE_DEPTH / 2.0
	# Both surfaces get the back material (no distinct top face needed)
	mi.set_surface_override_material(0, _back_material)
	mi.set_surface_override_material(1, _back_material)
	root.add_child(mi)

	return root


# ── Seat wind labels ──────────────────────────────────────────

func _create_seat_wind_labels() -> void:
	for i: int in range(4):
		var label: Label3D = Label3D.new()
		label.font_size = 72
		label.pixel_size = 0.0008
		label.modulate = Color(1.0, 0.9, 0.3)
		label.outline_modulate = Color.BLACK
		label.outline_size = 16
		label.rotation.x = -PI / 2.0

		# Place near the center, inside the pond area
		match i:
			0: label.position = Vector3(0, 0.012, 0.05)
			1: label.position = Vector3(0.05, 0.012, 0)
			2: label.position = Vector3(0, 0.012, -0.05)
			3: label.position = Vector3(-0.05, 0.012, 0)

		# Rotate text to face the player it belongs to
		match i:
			1: label.rotation.z = PI / 2.0
			2: label.rotation.z = PI
			3: label.rotation.z = -PI / 2.0

		add_child(label)
		wind_label_nodes[i] = label


func _update_seat_wind_labels() -> void:
	for i: int in range(4):
		if wind_label_nodes[i] != null and round_state != null:
			var w: Tile.Wind = round_state.players[i].wind
			wind_label_nodes[i].text = Tile.wind_to_string(w).substr(0, 1)


# ── Riichi sticks ─────────────────────────────────────────────

func _update_riichi_sticks() -> void:
	for i: int in range(4):
		var in_riichi: bool = round_state.players[i].in_riichi
		var existing: Node3D = riichi_stick_nodes[i]

		if in_riichi and existing == null:
			# Create a riichi stick
			var stick: MeshInstance3D = MeshInstance3D.new()
			var mesh: BoxMesh = BoxMesh.new()
			mesh.size = Vector3(0.2, 0.006, 0.012)
			stick.mesh = mesh

			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 1.0, 1.0)
			stick.material_override = mat

			# Red dot in middle (simplified — small red cube)
			var dot: MeshInstance3D = MeshInstance3D.new()
			var dot_mesh: BoxMesh = BoxMesh.new()
			dot_mesh.size = Vector3(0.012, 0.008, 0.014)
			dot.mesh = dot_mesh
			var dot_mat: StandardMaterial3D = StandardMaterial3D.new()
			dot_mat.albedo_color = Color(0.9, 0.2, 0.2)
			dot.material_override = dot_mat
			stick.add_child(dot)

			# Position in front of player
			match i:
				0: stick.position = Vector3(0, 0.015, POND_START_Z - 0.04)
				1: stick.position = Vector3(POND_START_Z - 0.04, 0.015, 0)
				2: stick.position = Vector3(0, 0.015, -(POND_START_Z - 0.04))
				3: stick.position = Vector3(-(POND_START_Z - 0.04), 0.015, 0)

			if i == 1 or i == 3:
				stick.rotation.y = PI / 2.0

			add_child(stick)
			riichi_stick_nodes[i] = stick

		elif not in_riichi and existing != null:
			existing.queue_free()
			riichi_stick_nodes[i] = null


func _update_all_ponds() -> void:
	for player_nodes: Array in pond_tile_nodes:
		for node: Node3D in player_nodes:
			node.queue_free()
		player_nodes.clear()

	for i: int in range(4):
		for tile: Tile in round_state.players[i].pond:
			_add_pond_tile(i, tile)

	# Refresh opponent hand tile counts, melds, dora, and riichi sticks
	_render_opponent_hands()
	_update_all_melds()
	_render_dora_indicators()
	_update_riichi_sticks()


const TILE_BODY_COLOR: Color = Color(0.88, 0.78, 0.55)   # Straw
const TILE_FACE_COLOR: Color = Color(0.98, 0.97, 0.93)   # Off-white
const TILE_BACK_COLOR: Color = Color(0.85, 0.55, 0.15)   # Orange (face-down)
const TILE_GLYPH_COLOR: Color = Color(0.08, 0.08, 0.08)  # Near-black

# Cached meshes (built once, shared by all tiles)
var _flat_tile_mesh: ArrayMesh = null       # Laid-flat tile (pond/meld)
var _upright_tile_mesh: ArrayMesh = null    # Standing tile (hand)
var _back_flat_mesh: ArrayMesh = null       # Face-down flat
var _back_upright_mesh: ArrayMesh = null    # Face-down upright

# Cached materials
var _body_material: StandardMaterial3D = null
var _face_material: StandardMaterial3D = null
var _back_material: StandardMaterial3D = null


## Create a pond tile — laid flat on the table, face up.
func _create_pond_tile_mesh(tile: Tile) -> Node3D:
	_ensure_tile_meshes()
	var root: Node3D = Node3D.new()

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _flat_tile_mesh
	mi.position.y = TILE_DEPTH / 2.0
	mi.set_surface_override_material(0, _body_material)
	mi.set_surface_override_material(1, _face_material)
	root.add_child(mi)

	_add_tile_glyph(root, tile, TILE_DEPTH + 0.0005)
	return root


## Create a hand tile — standing upright with optional face.
func _create_tile_mesh(tile: Tile, face_up: bool) -> Node3D:
	_ensure_tile_meshes()
	var root: Node3D = Node3D.new()

	var mi: MeshInstance3D = MeshInstance3D.new()

	if face_up and tile != null:
		mi.mesh = _upright_tile_mesh
		mi.position.y = TILE_HEIGHT / 2.0
		mi.set_surface_override_material(0, _body_material)
		mi.set_surface_override_material(1, _face_material)
		root.add_child(mi)
		_add_tile_glyph(root, tile, TILE_HEIGHT + 0.0005)
	else:
		mi.mesh = _back_upright_mesh
		mi.position.y = TILE_HEIGHT / 2.0
		mi.set_surface_override_material(0, _back_material)
		root.add_child(mi)

	return root


## Build all shared tile meshes once. Called lazily on first tile creation.
func _ensure_tile_meshes() -> void:
	if _flat_tile_mesh != null:
		return

	_flat_tile_mesh = _build_two_tone_box(TILE_WIDTH, TILE_DEPTH, TILE_HEIGHT)
	_upright_tile_mesh = _build_two_tone_box(TILE_WIDTH, TILE_HEIGHT, TILE_DEPTH)
	_back_upright_mesh = _build_two_tone_box(TILE_WIDTH, TILE_HEIGHT, TILE_DEPTH)
	_back_flat_mesh = _build_two_tone_box(TILE_WIDTH, TILE_DEPTH, TILE_HEIGHT)

	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = TILE_BODY_COLOR

	_face_material = StandardMaterial3D.new()
	_face_material.albedo_color = TILE_FACE_COLOR

	_back_material = StandardMaterial3D.new()
	_back_material.albedo_color = TILE_BACK_COLOR


## Build a box mesh with 2 surfaces: surface 0 = body (bottom + 4 sides),
## surface 1 = top face. Each surface can be assigned a different material.
## Vertices are centered at origin; box spans -w/2..w/2, -h/2..h/2, -d/2..d/2.
func _build_two_tone_box(w: float, h: float, d: float) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()

	var hw: float = w * 0.5
	var hh: float = h * 0.5
	var hd: float = d * 0.5

	# 8 corners: (x_sign, y_sign, z_sign)
	var c_nnn: Vector3 = Vector3(-hw, -hh, -hd)
	var c_pnn: Vector3 = Vector3( hw, -hh, -hd)
	var c_npn: Vector3 = Vector3(-hw,  hh, -hd)
	var c_ppn: Vector3 = Vector3( hw,  hh, -hd)
	var c_nnp: Vector3 = Vector3(-hw, -hh,  hd)
	var c_pnp: Vector3 = Vector3( hw, -hh,  hd)
	var c_npp: Vector3 = Vector3(-hw,  hh,  hd)
	var c_ppp: Vector3 = Vector3( hw,  hh,  hd)

	# ── Surface 0: body (bottom + 4 sides) ──
	var body_verts: PackedVector3Array = PackedVector3Array()
	var body_normals: PackedVector3Array = PackedVector3Array()

	# Bottom face (y = -hh), normal (0, -1, 0)
	_append_quad(body_verts, body_normals, c_nnn, c_pnn, c_pnp, c_nnp, Vector3(0, -1, 0))
	# Back face (z = -hd), normal (0, 0, -1)
	_append_quad(body_verts, body_normals, c_pnn, c_nnn, c_npn, c_ppn, Vector3(0, 0, -1))
	# Front face (z = +hd), normal (0, 0, 1)
	_append_quad(body_verts, body_normals, c_nnp, c_pnp, c_ppp, c_npp, Vector3(0, 0, 1))
	# Left face (x = -hw), normal (-1, 0, 0)
	_append_quad(body_verts, body_normals, c_nnn, c_nnp, c_npp, c_npn, Vector3(-1, 0, 0))
	# Right face (x = +hw), normal (1, 0, 0)
	_append_quad(body_verts, body_normals, c_pnp, c_pnn, c_ppn, c_ppp, Vector3(1, 0, 0))

	var body_arrays: Array = []
	body_arrays.resize(Mesh.ARRAY_MAX)
	body_arrays[Mesh.ARRAY_VERTEX] = body_verts
	body_arrays[Mesh.ARRAY_NORMAL] = body_normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body_arrays)

	# ── Surface 1: top face ──
	var top_verts: PackedVector3Array = PackedVector3Array()
	var top_normals: PackedVector3Array = PackedVector3Array()

	# Top face (y = +hh), normal (0, 1, 0)
	_append_quad(top_verts, top_normals, c_npn, c_npp, c_ppp, c_ppn, Vector3(0, 1, 0))

	var top_arrays: Array = []
	top_arrays.resize(Mesh.ARRAY_MAX)
	top_arrays[Mesh.ARRAY_VERTEX] = top_verts
	top_arrays[Mesh.ARRAY_NORMAL] = top_normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, top_arrays)

	return mesh


## Append 2 triangles (forming a quad) with CCW winding from v1 → v2 → v3 → v4.
func _append_quad(verts: PackedVector3Array, normals: PackedVector3Array,
				  v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3, n: Vector3) -> void:
	verts.append(v1)
	verts.append(v2)
	verts.append(v3)
	verts.append(v1)
	verts.append(v3)
	verts.append(v4)
	for _i: int in range(6):
		normals.append(n)


## Draw the unicode mahjong character as a black glyph on the tile face.
func _add_tile_glyph(root: Node3D, tile: Tile, y: float) -> void:
	var glyph: Label3D = Label3D.new()
	glyph.text = Tile.unicode_char(tile.tile_type)
	glyph.font_size = 96
	glyph.pixel_size = 0.00048
	glyph.position = Vector3(0, y, 0)
	glyph.rotation.x = -PI / 2.0
	glyph.modulate = TILE_GLYPH_COLOR
	glyph.outline_size = 0
	root.add_child(glyph)


func _get_tile_color(tile: Tile) -> Color:
	var t: int = int(tile.tile_type)
	if t >= int(Tile.TileType.MAN1) and t <= int(Tile.TileType.MAN9):
		return SUIT_COLORS["man"]
	if t >= int(Tile.TileType.PIN1) and t <= int(Tile.TileType.PIN9):
		return SUIT_COLORS["pin"]
	if t >= int(Tile.TileType.SOU1) and t <= int(Tile.TileType.SOU9):
		return SUIT_COLORS["sou"]
	return SUIT_COLORS["honor"]


func _clear_all_tiles() -> void:
	for node: Node3D in hand_tile_nodes:
		if is_instance_valid(node):
			node.queue_free()
	hand_tile_nodes.clear()

	for opp_nodes: Array in opponent_hand_nodes:
		for node: Node3D in opp_nodes:
			if is_instance_valid(node):
				node.queue_free()
	opponent_hand_nodes.clear()

	for player_nodes: Array in pond_tile_nodes:
		for node: Node3D in player_nodes:
			if is_instance_valid(node):
				node.queue_free()
		player_nodes.clear()

	for meld_nodes: Array in meld_tile_nodes:
		for node: Node3D in meld_nodes:
			if is_instance_valid(node):
				node.queue_free()
		meld_nodes.clear()

	for node: Node3D in dora_tile_nodes:
		if is_instance_valid(node):
			node.queue_free()
	dora_tile_nodes.clear()

	for i: int in range(riichi_stick_nodes.size()):
		if is_instance_valid(riichi_stick_nodes[i]):
			riichi_stick_nodes[i].queue_free()
		riichi_stick_nodes[i] = null


# ── HUD interface ──────────────────────────────────────────────

func _show_call_buttons(calls: Dictionary) -> void:
	if hud != null:
		hud.show_call_buttons(calls)


func _hide_call_buttons() -> void:
	if hud != null:
		hud.hide_call_buttons()


var _cached_shanten: int = 2
var _cached_waits_text: String = ""
var _shanten_dirty: bool = true

func _update_hud() -> void:
	if hud == null:
		return

	# Only recalculate shanten when the player's hand changed
	if _shanten_dirty:
		var player: RoundStatePlayer = round_state.players[PLAYER_INDEX]
		var calls_for_rules: Array = player.calls

		# Use in_tenpai first (fast) before the full shanten calc
		if TileRules.in_tenpai(player.hand, calls_for_rules):
			_cached_shanten = 0
			var waits: Array = TileRules.waiting_tiles(player.hand, calls_for_rules)
			var wait_names: Array = []
			for w: Tile in waits:
				wait_names.append(Tile.compact_name(w.tile_type))
			_cached_waits_text = ", ".join(wait_names)
		else:
			_cached_shanten = TileRules.get_shanten(player.hand, calls_for_rules)
			_cached_waits_text = ""
		_shanten_dirty = false

	hud.update_info(
		game_state.player_scores,
		_cached_shanten,
		_cached_waits_text,
		Tile.wind_to_string(round_state.round_wind),
		game_state.current_round,
		round_state.wall.wall_tiles.size()
	)
