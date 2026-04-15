## round_state_wall.gd — Tile wall management for a single round.
##
## Creates 136 tiles (4 of each 34 types), shuffles them, and manages
## the draw pile, dead wall, and dora indicators.
class_name RoundStateWall
extends RefCounted


# ── Properties ─────────────────────────────────────────────────

var wall_tiles: Array = []          # Main draw pile (starts with ~122 tiles)
var dead_wall_tiles: Array = []     # Dead wall (14 tiles: kan replacements + dora)
var dora: Array = []                # Revealed dora indicator tiles
var ura_dora: Array = []            # Hidden ura-dora (revealed on riichi win)
var newest_dora: Tile = null
var dora_index: int = 4             # Pointer into dead wall for dora pairs
var all_tiles: Array = []           # All 136 tiles for reference


# ── Accessors ──────────────────────────────────────────────────

var empty: bool:
	get: return wall_tiles.size() == 0

var can_kan: bool:
	get: return dora.size() < 5

var can_call: bool:
	get: return wall_tiles.size() > 0

var can_riichi: bool:
	get: return wall_tiles.size() >= 4


# ── Build & shuffle ────────────────────────────────────────────

func build_and_shuffle() -> void:
	all_tiles.clear()
	wall_tiles.clear()
	dead_wall_tiles.clear()
	dora.clear()
	ura_dora.clear()
	dora_index = 4

	# Create 136 tiles: 4 copies of each of 34 types
	var tile_id: int = 0
	for raw_type: int in range(int(Tile.TileType.MAN1), int(Tile.TileType.CHUN) + 1):
		for _copy: int in range(4):
			var tile: Tile = Tile.new(tile_id, raw_type as Tile.TileType)
			all_tiles.append(tile)
			tile_id += 1

	# Shuffle
	var shuffled: Array = all_tiles.duplicate()
	shuffled.shuffle()

	# Split: first 122 → draw pile, last 14 → dead wall
	for i: int in range(122):
		wall_tiles.append(shuffled[i])
	for i: int in range(122, 136):
		dead_wall_tiles.append(shuffled[i])

	# Reveal first dora
	flip_dora()


# ── Draw operations ────────────────────────────────────────────

func draw_wall() -> Tile:
	assert(wall_tiles.size() > 0, "Tried to draw from empty wall")
	return wall_tiles.pop_front()


func draw_dead_wall() -> Tile:
	assert(dead_wall_tiles.size() > 0, "Tried to draw from empty dead wall")
	var tile: Tile = dead_wall_tiles.pop_front()

	# Move last wall tile to dead wall to maintain dead wall size
	if wall_tiles.size() > 0:
		var replacement: Tile = wall_tiles.pop_back()
		dead_wall_tiles.append(replacement)

	return tile


# ── Dora ───────────────────────────────────────────────────────

func flip_dora() -> void:
	if dora_index >= dead_wall_tiles.size():
		return
	var dora_tile: Tile = dead_wall_tiles[dora_index]
	dora.append(dora_tile)
	newest_dora = dora_tile

	if dora_index + 1 < dead_wall_tiles.size():
		ura_dora.append(dead_wall_tiles[dora_index + 1])

	dora_index += 2
