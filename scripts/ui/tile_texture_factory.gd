## tile_texture_factory.gd — Generates tile face textures.
##
## On first use, renders each of the 34 tile faces into a hidden SubViewport
## and caches the result as an ImageTexture. If a PNG file exists at
## res://assets/tiles/<code_name>.png, it is used instead.
##
## Usage:
##   var factory := TileTextureFactory.new()
##   add_child(factory)
##   factory.generate_all(func():
##       var tex = TileTextureFactory.get_texture(Tile.TileType.MAN5)
##       ...
##   )
class_name TileTextureFactory
extends Node


const TEX_WIDTH: int = 128
const TEX_HEIGHT: int = 192
const BORDER_PAD: int = 6
const BORDER_THICKNESS: int = 3
const BG_COLOR: Color = Color(0.96, 0.95, 0.88)
const FONT_SIZE_SUIT: int = 120
const FONT_SIZE_HONOR: int = 100
const ASSET_DIR: String = "res://assets/tiles/"

static var _textures: Dictionary = {}       # Tile.TileType -> Texture2D
static var _generation_started: bool = false
static var _generation_complete: bool = false

var _viewport: SubViewport = null
var _draw_root: Control = null


# ── Public API ─────────────────────────────────────────────────

## Generate all 34 tile textures and invoke callback when done.
## Subsequent calls re-use cached textures.
func generate_all(on_complete: Callable = Callable()) -> void:
	if _generation_complete:
		if on_complete.is_valid():
			on_complete.call()
		return

	if _generation_started:
		# Already generating — schedule callback
		return

	_generation_started = true
	_setup_viewport()

	# Iterate all tile types in order
	var all_types: Array = []
	for raw_type: int in range(int(Tile.TileType.MAN1), int(Tile.TileType.CHUN) + 1):
		all_types.append(raw_type as Tile.TileType)

	for type: Tile.TileType in all_types:
		var texture: Texture2D = await _get_or_generate(type)
		_textures[type] = texture

	_generation_complete = true

	if on_complete.is_valid():
		on_complete.call()

	# Clean up the factory — textures are cached statically
	queue_free()


## Retrieve a generated texture (null if not yet generated).
static func get_texture(type: Tile.TileType) -> Texture2D:
	return _textures.get(type)


## True if all textures have been generated.
static func is_ready() -> bool:
	return _generation_complete


# ── Viewport setup ─────────────────────────────────────────────

func _setup_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(TEX_WIDTH, TEX_HEIGHT)
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)

	_draw_root = Control.new()
	_draw_root.size = Vector2(TEX_WIDTH, TEX_HEIGHT)
	_viewport.add_child(_draw_root)


# ── Per-tile generation ────────────────────────────────────────

func _get_or_generate(type: Tile.TileType) -> Texture2D:
	# Prefer a user-provided PNG if one exists
	var asset_path: String = ASSET_DIR + Tile.code_name(type) + ".png"
	if ResourceLoader.exists(asset_path):
		return load(asset_path)

	return await _generate_procedural(type)


func _generate_procedural(type: Tile.TileType) -> ImageTexture:
	_clear_draw_root()

	var glyph_color: Color = Tile.glyph_color(type)
	var is_honor: bool = Tile.is_honor_type(type)

	# Background
	var bg: ColorRect = ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(TEX_WIDTH, TEX_HEIGHT)
	_draw_root.add_child(bg)

	# Border — only on honor tiles. The unicode mahjong glyphs for
	# Man/Pin/Sou already include their own frame, so adding another
	# border doubles it up.
	if is_honor:
		_add_border(glyph_color)

	# Glyph
	var label: Label = Label.new()
	label.text = Tile.unicode_char(type)
	label.add_theme_font_override("font", _get_cjk_font())
	label.add_theme_color_override("font_color", glyph_color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0

	var font_size: int = FONT_SIZE_HONOR if is_honor else FONT_SIZE_SUIT
	label.add_theme_font_size_override("font_size", font_size)
	_draw_root.add_child(label)

	# Trigger a render and wait for two frames to ensure the output is ready
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var img: Image = _viewport.get_texture().get_image()

	# Write the generated PNG directly into the project's assets/tiles/
	# folder so it can be opened and edited.
	var asset_path: String = ProjectSettings.globalize_path(
		ASSET_DIR + Tile.code_name(type) + ".png"
	)
	var err: int = img.save_png(asset_path)
	if err != OK:
		push_error("Failed to save tile PNG to %s (error %d)" % [asset_path, err])
	else:
		print("Saved tile texture: %s" % asset_path)

	return ImageTexture.create_from_image(img)


func _add_border(color: Color) -> void:
	var pad: int = BORDER_PAD
	var thick: int = BORDER_THICKNESS

	# Top
	var top: ColorRect = ColorRect.new()
	top.color = color
	top.position = Vector2(pad, pad)
	top.size = Vector2(TEX_WIDTH - 2 * pad, thick)
	_draw_root.add_child(top)

	# Bottom
	var bot: ColorRect = ColorRect.new()
	bot.color = color
	bot.position = Vector2(pad, TEX_HEIGHT - pad - thick)
	bot.size = Vector2(TEX_WIDTH - 2 * pad, thick)
	_draw_root.add_child(bot)

	# Left
	var left: ColorRect = ColorRect.new()
	left.color = color
	left.position = Vector2(pad, pad)
	left.size = Vector2(thick, TEX_HEIGHT - 2 * pad)
	_draw_root.add_child(left)

	# Right
	var right: ColorRect = ColorRect.new()
	right.color = color
	right.position = Vector2(TEX_WIDTH - pad - thick, pad)
	right.size = Vector2(thick, TEX_HEIGHT - 2 * pad)
	_draw_root.add_child(right)


func _clear_draw_root() -> void:
	var children: Array = _draw_root.get_children()
	for child: Node in children:
		_draw_root.remove_child(child)
		child.free()


func _get_cjk_font() -> Font:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray([
		"Hiragino Sans",
		"Hiragino Kaku Gothic ProN",
		"PingFang SC",
		"Noto Sans CJK JP",
		"Noto Sans CJK SC",
		"MS Gothic",
		"Yu Gothic",
		"Arial Unicode MS",
		"sans-serif",
	])
	return font
