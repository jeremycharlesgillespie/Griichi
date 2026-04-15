extends Control

const DOMINO_WIDTH: float = 0.032     # 32mm — longest (X axis)
const DOMINO_HEIGHT: float = 0.016    # 16mm — thickness (Y axis, when laid flat)
const DOMINO_DEPTH: float = 0.024     # 24mm — width of top face (Z axis)
const DOMINO_ROTATION_SPEED: float = 0.8   # radians/sec

const DOMINO_COLOR: Color = Color(0.88, 0.78, 0.55)   # Straw body

# Which tiles to cycle through in the preview
const PREVIEW_TILE_TYPES: Array[Tile.TileType] = [
	Tile.TileType.MAN1, Tile.TileType.MAN5, Tile.TileType.MAN9,
	Tile.TileType.PIN3, Tile.TileType.PIN7,
	Tile.TileType.SOU2, Tile.TileType.SOU8,
	Tile.TileType.TON, Tile.TileType.NAN, Tile.TileType.SHAA, Tile.TileType.PEI,
	Tile.TileType.CHUN, Tile.TileType.HATSU, Tile.TileType.HAKU,
]

const GLYPH_SWAP_INTERVAL: float = 1.5

var domino_node: Node3D = null
var face_material: StandardMaterial3D = null
var preview_index: int = 0
var glyph_swap_timer: float = 0.0

@onready var tile_viewport: SubViewport = $TilePreview/SubViewportContainer/SubViewport


func _ready() -> void:
	print("GRiichi loaded — generating tile textures…")

	# Kick off texture generation. When done, spawn the domino.
	var factory: TileTextureFactory = TileTextureFactory.new()
	add_child(factory)
	factory.generate_all(_on_textures_ready)


func _on_textures_ready() -> void:
	print("Tile textures ready.")
	_spawn_domino()


func _process(delta: float) -> void:
	if domino_node != null:
		domino_node.rotation.y += DOMINO_ROTATION_SPEED * delta

	# Cycle through different tile glyphs so we can verify rendering
	glyph_swap_timer += delta
	if glyph_swap_timer >= GLYPH_SWAP_INTERVAL:
		glyph_swap_timer = 0.0
		preview_index = (preview_index + 1) % PREVIEW_TILE_TYPES.size()
		_apply_face_texture(PREVIEW_TILE_TYPES[preview_index])


# ── Domino construction ─────────────────────────────────────

func _spawn_domino() -> void:
	if tile_viewport == null:
		return

	var world: Node3D = tile_viewport.get_node("World")

	# Clear any prior preview geometry
	for child: Node in world.get_children():
		if child.name == "Domino":
			child.queue_free()

	domino_node = Node3D.new()
	domino_node.name = "Domino"
	domino_node.position = Vector3(0, 0, 0)
	world.add_child(domino_node)

	# Body: straw BoxMesh
	var body: MeshInstance3D = MeshInstance3D.new()
	var body_mesh: BoxMesh = BoxMesh.new()
	body_mesh.size = Vector3(DOMINO_WIDTH, DOMINO_HEIGHT, DOMINO_DEPTH)
	body.mesh = body_mesh
	var body_mat: StandardMaterial3D = StandardMaterial3D.new()
	body_mat.albedo_color = DOMINO_COLOR
	body.material_override = body_mat
	domino_node.add_child(body)

	# Top face: a flat PlaneMesh sitting just above the body's top surface,
	# textured with the tile face. The texture is 128×192 (portrait); the
	# tile's top face is 32×24 (landscape). Rotate the plane 90° around Y
	# so the texture's long dimension aligns with the tile's long axis.
	var face: MeshInstance3D = MeshInstance3D.new()
	var face_mesh: PlaneMesh = PlaneMesh.new()
	face_mesh.size = Vector2(DOMINO_DEPTH, DOMINO_WIDTH)   # Swapped: plane rotates 90°
	face.mesh = face_mesh
	face.position = Vector3(0, DOMINO_HEIGHT * 0.5 + 0.0005, 0)
	face.rotation = Vector3(0, PI / 2.0, 0)

	face_material = StandardMaterial3D.new()
	face_material.albedo_color = Color.WHITE
	face.material_override = face_material
	domino_node.add_child(face)

	_apply_face_texture(PREVIEW_TILE_TYPES[preview_index])

	print("Domino spawned. Texture cache size: ", _texture_cache_count())


func _texture_cache_count() -> int:
	var count: int = 0
	for type: Tile.TileType in PREVIEW_TILE_TYPES:
		if TileTextureFactory.get_texture(type) != null:
			count += 1
	return count


func _apply_face_texture(type: Tile.TileType) -> void:
	if face_material == null:
		return
	var tex: Texture2D = TileTextureFactory.get_texture(type)
	if tex != null:
		face_material.albedo_texture = tex


# ── Mesh construction (matches tile_renderer.gd) ────────────

func _build_two_tone_box(w: float, h: float, d: float) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var hw: float = w * 0.5
	var hh: float = h * 0.5
	var hd: float = d * 0.5

	# 8 corners
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
	var body_uvs: PackedVector2Array = PackedVector2Array()

	# Bottom (y = -hh), normal (0, -1, 0)
	_append_quad_plain(body_verts, body_normals, body_uvs,
		c_nnn, c_nnp, c_pnp, c_pnn, Vector3(0, -1, 0))
	# Back (z = -hd)
	_append_quad_plain(body_verts, body_normals, body_uvs,
		c_pnn, c_ppn, c_npn, c_nnn, Vector3(0, 0, -1))
	# Front (z = +hd)
	_append_quad_plain(body_verts, body_normals, body_uvs,
		c_nnp, c_npp, c_ppp, c_pnp, Vector3(0, 0, 1))
	# Left (x = -hw)
	_append_quad_plain(body_verts, body_normals, body_uvs,
		c_nnn, c_npn, c_npp, c_nnp, Vector3(-1, 0, 0))
	# Right (x = +hw)
	_append_quad_plain(body_verts, body_normals, body_uvs,
		c_pnp, c_ppp, c_ppn, c_pnn, Vector3(1, 0, 0))

	var body_arrays: Array = []
	body_arrays.resize(Mesh.ARRAY_MAX)
	body_arrays[Mesh.ARRAY_VERTEX] = body_verts
	body_arrays[Mesh.ARRAY_NORMAL] = body_normals
	body_arrays[Mesh.ARRAY_TEX_UV] = body_uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body_arrays)

	# ── Surface 1: top face (textured) ──
	# UV mapping: v1 = (0,0) top-left, v2 = (0,1) bottom-left, v3 = (1,1) BR, v4 = (1,0) TR.
	# The texture is 128x192 (2:3 portrait). The top face of the domino is
	# 32mm (X) × 24mm (Z) — a 4:3 landscape proportion. We map the texture
	# so that it reads with text running along the tile's long axis (X).
	var top_verts: PackedVector3Array = PackedVector3Array()
	var top_normals: PackedVector3Array = PackedVector3Array()
	var top_uvs: PackedVector2Array = PackedVector2Array()

	# Top face (y = +hh), corners CCW from above:
	#   c_npn (X-,Z-)  →  c_npp (X-,Z+)  →  c_ppp (X+,Z+)  →  c_ppn (X+,Z-)
	# Texture UV:
	#   (0,0) is top-left of texture (short side at top).
	#   We want the texture rotated 90° so the long axis of the tile shows
	#   the full 192px height of the texture.
	var uv1: Vector2 = Vector2(1, 0)  # c_npn → texture top-right
	var uv2: Vector2 = Vector2(0, 0)  # c_npp → texture top-left
	var uv3: Vector2 = Vector2(0, 1)  # c_ppp → texture bottom-left
	var uv4: Vector2 = Vector2(1, 1)  # c_ppn → texture bottom-right

	# Triangle 1: npn → npp → ppp
	top_verts.append(c_npn); top_uvs.append(uv1)
	top_verts.append(c_npp); top_uvs.append(uv2)
	top_verts.append(c_ppp); top_uvs.append(uv3)
	# Triangle 2: npn → ppp → ppn
	top_verts.append(c_npn); top_uvs.append(uv1)
	top_verts.append(c_ppp); top_uvs.append(uv3)
	top_verts.append(c_ppn); top_uvs.append(uv4)
	for _i: int in range(6):
		top_normals.append(Vector3(0, 1, 0))

	var top_arrays: Array = []
	top_arrays.resize(Mesh.ARRAY_MAX)
	top_arrays[Mesh.ARRAY_VERTEX] = top_verts
	top_arrays[Mesh.ARRAY_NORMAL] = top_normals
	top_arrays[Mesh.ARRAY_TEX_UV] = top_uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, top_arrays)

	return mesh


func _append_quad_plain(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array,
						v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3, n: Vector3) -> void:
	verts.append(v1); verts.append(v2); verts.append(v3)
	verts.append(v1); verts.append(v3); verts.append(v4)
	for _i: int in range(6):
		normals.append(n)
		uvs.append(Vector2(0, 0))  # Body faces don't use textures, UV doesn't matter


# ── Menu button handlers ────────────────────────────────────

func _on_singleplayer_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
