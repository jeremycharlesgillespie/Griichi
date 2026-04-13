## tile.gd — Tile types, Tile class, and helper enums.
##
## Ported from OpenRiichi source/Game/Logic/Tile.vala.
## All 34 tile types in standard riichi mahjong, plus Wind/TileType
## enums and human-readable name formatters.
class_name Tile
extends RefCounted

enum TileType {
	BLANK,
	MAN1, MAN2, MAN3, MAN4, MAN5, MAN6, MAN7, MAN8, MAN9,
	PIN1, PIN2, PIN3, PIN4, PIN5, PIN6, PIN7, PIN8, PIN9,
	SOU1, SOU2, SOU3, SOU4, SOU5, SOU6, SOU7, SOU8, SOU9,
	TON, NAN, SHAA, PEI,
	HAKU, HATSU, CHUN
}

enum Wind { EAST, SOUTH, WEST, NORTH }

var id: int
var tile_type: TileType
var dora: bool

func _init(tile_id: int = 0, type: TileType = TileType.BLANK, is_dora: bool = false) -> void:
	id = tile_id
	tile_type = type
	dora = is_dora

# ── Type queries ────────────────────────────────────────────────

func is_suit_tile() -> bool:
	return (tile_type >= TileType.MAN1 and tile_type <= TileType.MAN9) \
		or (tile_type >= TileType.PIN1 and tile_type <= TileType.PIN9) \
		or (tile_type >= TileType.SOU1 and tile_type <= TileType.SOU9)

func is_honor_tile() -> bool:
	return is_wind_tile() or is_dragon_tile()

func is_dragon_tile() -> bool:
	return tile_type in [TileType.HAKU, TileType.HATSU, TileType.CHUN]

func is_wind_tile() -> bool:
	return tile_type in [TileType.TON, TileType.NAN, TileType.SHAA, TileType.PEI]

func is_terminal_tile() -> bool:
	return tile_type in [TileType.MAN1, TileType.MAN9,
						 TileType.PIN1, TileType.PIN9,
						 TileType.SOU1, TileType.SOU9]

func is_same_sort(other: Tile) -> bool:
	if tile_type >= TileType.MAN1 and tile_type <= TileType.MAN9 \
		and other.tile_type >= TileType.MAN1 and other.tile_type <= TileType.MAN9:
		return true
	if tile_type >= TileType.PIN1 and tile_type <= TileType.PIN9 \
		and other.tile_type >= TileType.PIN1 and other.tile_type <= TileType.PIN9:
		return true
	if tile_type >= TileType.SOU1 and tile_type <= TileType.SOU9 \
		and other.tile_type >= TileType.SOU1 and other.tile_type <= TileType.SOU9:
		return true
	return tile_type == other.tile_type

func is_neighbour(other: Tile) -> bool:
	if not is_suit_tile() or not other.is_suit_tile() or not is_same_sort(other):
		return false
	return absi(int(tile_type) - int(other.tile_type)) == 1

func is_second_neighbour(other: Tile) -> bool:
	if not is_suit_tile() or not other.is_suit_tile() or not is_same_sort(other):
		return false
	return absi(int(tile_type) - int(other.tile_type)) == 2

func is_wind(wind: Wind) -> bool:
	return (tile_type == TileType.TON  and wind == Wind.EAST) \
		or (tile_type == TileType.NAN  and wind == Wind.SOUTH) \
		or (tile_type == TileType.SHAA and wind == Wind.WEST) \
		or (tile_type == TileType.PEI  and wind == Wind.NORTH)

func get_number_index() -> int:
	if tile_type >= TileType.MAN1 and tile_type <= TileType.MAN9:
		return tile_type - TileType.MAN1
	if tile_type >= TileType.PIN1 and tile_type <= TileType.PIN9:
		return tile_type - TileType.PIN1
	if tile_type >= TileType.SOU1 and tile_type <= TileType.SOU9:
		return tile_type - TileType.SOU1
	return 0

func equals(other: Tile) -> bool:
	return id == other.id and tile_type == other.tile_type and dora == other.dora

# ── Name formatters ─────────────────────────────────────────────

## Short notation: "1m", "5p", "7s", "E", "Wh", etc.
static func compact_name(type: TileType) -> String:
	var t: int = int(type)
	if t >= int(TileType.MAN1) and t <= int(TileType.MAN9):
		return str(t - int(TileType.MAN1) + 1) + "m"
	if t >= int(TileType.PIN1) and t <= int(TileType.PIN9):
		return str(t - int(TileType.PIN1) + 1) + "p"
	if t >= int(TileType.SOU1) and t <= int(TileType.SOU9):
		return str(t - int(TileType.SOU1) + 1) + "s"
	match type:
		TileType.TON:   return "E"
		TileType.NAN:   return "S"
		TileType.SHAA:  return "W"
		TileType.PEI:   return "N"
		TileType.HAKU:  return "Wh"
		TileType.HATSU: return "Gr"
		TileType.CHUN:  return "Rd"
	return "?"

## Human-readable: "2 of Bamboo", "East Wind", "Red Dragon", etc.
static func readable_name(type: TileType) -> String:
	var t: int = int(type)
	if t >= int(TileType.MAN1) and t <= int(TileType.MAN9):
		return str(t - int(TileType.MAN1) + 1) + " of Characters"
	if t >= int(TileType.PIN1) and t <= int(TileType.PIN9):
		return str(t - int(TileType.PIN1) + 1) + " of Circles"
	if t >= int(TileType.SOU1) and t <= int(TileType.SOU9):
		return str(t - int(TileType.SOU1) + 1) + " of Bamboo"
	match type:
		TileType.TON:   return "East Wind"
		TileType.NAN:   return "South Wind"
		TileType.SHAA:  return "West Wind"
		TileType.PEI:   return "North Wind"
		TileType.HAKU:  return "White Dragon"
		TileType.HATSU: return "Green Dragon"
		TileType.CHUN:  return "Red Dragon"
	return "Unknown"

## Internal code name: "Man1", "Pin5", "Ton", etc.
static func code_name(type: TileType) -> String:
	var t: int = int(type)
	if t >= int(TileType.MAN1) and t <= int(TileType.MAN9):
		return "Man" + str(t - int(TileType.MAN1) + 1)
	if t >= int(TileType.PIN1) and t <= int(TileType.PIN9):
		return "Pin" + str(t - int(TileType.PIN1) + 1)
	if t >= int(TileType.SOU1) and t <= int(TileType.SOU9):
		return "Sou" + str(t - int(TileType.SOU1) + 1)
	match type:
		TileType.TON:   return "Ton"
		TileType.NAN:   return "Nan"
		TileType.SHAA:  return "Shaa"
		TileType.PEI:   return "Pei"
		TileType.HAKU:  return "Haku"
		TileType.HATSU: return "Hatsu"
		TileType.CHUN:  return "Chun"
	return "Blank"

# ── Wind helpers ────────────────────────────────────────────────

static func wind_to_string(wind: Wind) -> String:
	match wind:
		Wind.EAST:  return "East"
		Wind.SOUTH: return "South"
		Wind.WEST:  return "West"
		Wind.NORTH: return "North"
	return "Unknown"

static func next_wind(wind: Wind) -> Wind:
	match wind:
		Wind.EAST:  return Wind.SOUTH
		Wind.SOUTH: return Wind.WEST
		Wind.WEST:  return Wind.NORTH
	return Wind.EAST

static func int_to_wind(w: int) -> Wind:
	w = w % 4
	if w < 0:
		w += 4
	match w:
		0: return Wind.EAST
		1: return Wind.SOUTH
		2: return Wind.WEST
	return Wind.NORTH

# ── Dora indicator ──────────────────────────────────────────────

func dora_indicator() -> TileType:
	var t: int = int(tile_type)
	# Man suit wraps: 9m -> 1m
	if t >= int(TileType.MAN1) and t <= int(TileType.MAN8):
		return t + 1
	if tile_type == TileType.MAN9:
		return TileType.MAN1
	# Pin suit wraps
	if t >= int(TileType.PIN1) and t <= int(TileType.PIN8):
		return t + 1
	if tile_type == TileType.PIN9:
		return TileType.PIN1
	# Sou suit wraps
	if t >= int(TileType.SOU1) and t <= int(TileType.SOU8):
		return t + 1
	if tile_type == TileType.SOU9:
		return TileType.SOU1
	# Winds wrap: E->S->W->N->E
	if tile_type == TileType.TON:  return TileType.NAN
	if tile_type == TileType.NAN:  return TileType.SHAA
	if tile_type == TileType.SHAA: return TileType.PEI
	if tile_type == TileType.PEI:  return TileType.TON
	# Dragons wrap: Haku->Hatsu->Chun->Haku
	if tile_type == TileType.HAKU:  return TileType.HATSU
	if tile_type == TileType.HATSU: return TileType.CHUN
	if tile_type == TileType.CHUN:  return TileType.HAKU
	return TileType.BLANK

# ── Sorting ─────────────────────────────────────────────────────

static func sort_by_type(tiles: Array) -> Array:
	var sorted: Array = tiles.duplicate()
	sorted.sort_custom(func(a: Tile, b: Tile) -> bool:
		return int(a.tile_type) < int(b.tile_type))
	return sorted
