extends Control

func _ready() -> void:
	# Quick validation that the Tile class loaded correctly
	var tile: Tile = Tile.new(0, Tile.TileType.MAN1, false)
	print("GRiichi loaded! Test tile: ", Tile.readable_name(tile.tile_type))

func _on_singleplayer_pressed() -> void:
	print("TODO: Start singleplayer game")

func _on_quit_pressed() -> void:
	get_tree().quit()
