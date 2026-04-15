## generate_tile_textures.gd — Standalone tool to generate all tile PNGs.
##
## Run via:
##   godot --headless --script res://scripts/tools/generate_tile_textures.gd
##
## Writes 34 PNG files to /Users/…/GRiichi/assets/tiles/.
## Safe to run repeatedly — overwrites existing files.
extends SceneTree


func _initialize() -> void:
	print("Generating tile textures…")

	# TileTextureFactory requires a scene tree node (it creates a SubViewport).
	# Build the main loop scene structure manually.
	var root: Node = Node.new()
	root.name = "ToolRoot"
	get_root().add_child(root)

	var factory: TileTextureFactory = TileTextureFactory.new()
	root.add_child(factory)

	# Generate all textures, then quit.
	factory.generate_all(_on_complete.bind(root))


func _on_complete(root: Node) -> void:
	print("Done. Quitting.")
	root.queue_free()
	quit(0)
