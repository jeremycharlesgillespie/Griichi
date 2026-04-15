## bot.gd — Base class for AI players.
##
## Subclasses override get_discard_tile() and should_call_pon/chii
## to implement different strategies.
class_name Bot
extends RefCounted


# ── Turn decision ──────────────────────────────────────────────

## Choose which tile to discard. Called when it's this bot's turn
## and it must discard (after draw, no tsumo/kan/riichi).
func get_discard_tile(player: RoundStatePlayer, round_state: RoundState) -> Tile:
	# Default: discard the first legal tile
	var discardable: Array = player.get_discard_tiles()
	if discardable.size() > 0:
		return discardable[0]
	return player.newest_tile


## Whether the bot should declare riichi when eligible.
func should_declare_riichi(player: RoundStatePlayer, round_state: RoundState) -> bool:
	return true


## Whether the bot should call tsumo (self-draw win).
## Almost always true — override only for special cases.
func should_tsumo(player: RoundStatePlayer, round_state: RoundState) -> bool:
	return true


# ── Call decisions ─────────────────────────────────────────────

## Whether to call pon on the given discard tile.
func should_call_pon(player: RoundStatePlayer, round_state: RoundState) -> bool:
	return false


## Whether to call chii on the given discard tile.
## Returns null to skip, or [tile_1, tile_2] from hand to use.
func get_chii_tiles(player: RoundStatePlayer, round_state: RoundState) -> Array:
	return []


## Whether to call ron (discard win). Almost always true.
func should_call_ron(player: RoundStatePlayer, round_state: RoundState) -> bool:
	return true
