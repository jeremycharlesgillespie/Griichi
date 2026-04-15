## tile_renderer.gd — Static utilities for building 3D tile meshes.
##
## Used by game_controller.gd for all in-game tiles and by main_menu.gd
## for the tile preview on the launch screen. All geometry is built
## procedurally — no external 3D assets required.
class_name TileRenderer
extends RefCounted


# ── Dimensions ─────────────────────────────────────────────────

const TILE_WIDTH: float = 0.032
const TILE_HEIGHT: float = 0.042
const TILE_DEPTH: float = 0.022


# ── Colors ─────────────────────────────────────────────────────

const BODY_COLOR: Color = Color(0.88, 0.78, 0.55)   # Straw (sides + back)
const FACE_COLOR: Color = Color(0.98, 0.97, 0.93)   # Off-white (top)
const BACK_COLOR: Color = Color(0.85, 0.55, 0.15)   # Orange (face-down)
const GLYPH_COLOR: Color = Color(0.08, 0.08, 0.08)  # Near-black


# ── Public API ─────────────────────────────────────────────────

## Build an upright hand tile. If face_up is true, shows the tile's glyph
## on top. If false, tile is fully orange (face-down).
static func create_upright_tile(tile: Tile, face_up: bool = true) -> Node3D:
	var root: Node3D = Node3D.new()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _build_two_tone_box(TILE_WIDTH, TILE_HEIGHT, TILE_DEPTH)
	mi.position.y = TILE_HEIGHT / 2.0

	if face_up and tile != null:
		mi.set_surface_override_material(0, _body_material())
		mi.set_surface_override_material(1, _face_material())
		root.add_child(mi)
		_add_glyph(root, tile, TILE_HEIGHT + 0.0005)
	else:
		mi.set_surface_override_material(0, _back_material())
		mi.set_surface_override_material(1, _back_material())
		root.add_child(mi)

	return root


## Build a flat-laid tile (pond / meld). Always face-up with glyph.
static func create_flat_tile(tile: Tile) -> Node3D:
	var root: Node3D = Node3D.new()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _build_two_tone_box(TILE_WIDTH, TILE_DEPTH, TILE_HEIGHT)
	mi.position.y = TILE_DEPTH / 2.0
	mi.set_surface_override_material(0, _body_material())
	mi.set_surface_override_material(1, _face_material())
	root.add_child(mi)

	_add_glyph(root, tile, TILE_DEPTH + 0.0005)
	return root


## Build a flat-laid face-down tile (wall / dead wall).
static func create_flat_tile_back() -> Node3D:
	var root: Node3D = Node3D.new()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _build_two_tone_box(TILE_WIDTH, TILE_DEPTH, TILE_HEIGHT)
	mi.position.y = TILE_DEPTH / 2.0
	mi.set_surface_override_material(0, _back_material())
	mi.set_surface_override_material(1, _back_material())
	root.add_child(mi)
	return root


# ── Material helpers (cached) ─────────────────────────────────

static var _cached_body_mat: StandardMaterial3D = null
static var _cached_face_mat: StandardMaterial3D = null
static var _cached_back_mat: StandardMaterial3D = null


static func _body_material() -> StandardMaterial3D:
	if _cached_body_mat == null:
		_cached_body_mat = StandardMaterial3D.new()
		_cached_body_mat.albedo_color = BODY_COLOR
	return _cached_body_mat


static func _face_material() -> StandardMaterial3D:
	if _cached_face_mat == null:
		_cached_face_mat = StandardMaterial3D.new()
		_cached_face_mat.albedo_color = FACE_COLOR
	return _cached_face_mat


static func _back_material() -> StandardMaterial3D:
	if _cached_back_mat == null:
		_cached_back_mat = StandardMaterial3D.new()
		_cached_back_mat.albedo_color = BACK_COLOR
	return _cached_back_mat


# ── Mesh construction ─────────────────────────────────────────

## Build a 6-faced box mesh with 2 surfaces:
##   Surface 0: bottom + 4 sides (body material applied separately)
##   Surface 1: top face        (face material applied separately)
##
## Box is centered at origin and spans -w/2..w/2 (X), -h/2..h/2 (Y), -d/2..d/2 (Z).
## Top face has normal +Y.
static func _build_two_tone_box(w: float, h: float, d: float) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()

	var hw: float = w * 0.5
	var hh: float = h * 0.5
	var hd: float = d * 0.5

	# 8 corners (suffix = sign of x/y/z: n=negative, p=positive)
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

	# Bottom (y = -hh): normal (0, -1, 0) — winding goes CCW when viewed from below
	_quad(body_verts, body_normals, c_nnn, c_nnp, c_pnp, c_pnn, Vector3(0, -1, 0))
	# Back (z = -hd): normal (0, 0, -1)
	_quad(body_verts, body_normals, c_pnn, c_ppn, c_npn, c_nnn, Vector3(0, 0, -1))
	# Front (z = +hd): normal (0, 0, 1)
	_quad(body_verts, body_normals, c_nnp, c_npp, c_ppp, c_pnp, Vector3(0, 0, 1))
	# Left (x = -hw): normal (-1, 0, 0)
	_quad(body_verts, body_normals, c_nnn, c_npn, c_npp, c_nnp, Vector3(-1, 0, 0))
	# Right (x = +hw): normal (1, 0, 0)
	_quad(body_verts, body_normals, c_pnp, c_ppp, c_ppn, c_pnn, Vector3(1, 0, 0))

	var body_arrays: Array = []
	body_arrays.resize(Mesh.ARRAY_MAX)
	body_arrays[Mesh.ARRAY_VERTEX] = body_verts
	body_arrays[Mesh.ARRAY_NORMAL] = body_normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body_arrays)

	# ── Surface 1: top face ──
	var top_verts: PackedVector3Array = PackedVector3Array()
	var top_normals: PackedVector3Array = PackedVector3Array()

	# Top (y = +hh): normal (0, 1, 0) — CCW when viewed from above (+Y)
	_quad(top_verts, top_normals, c_npn, c_npp, c_ppp, c_ppn, Vector3(0, 1, 0))

	var top_arrays: Array = []
	top_arrays.resize(Mesh.ARRAY_MAX)
	top_arrays[Mesh.ARRAY_VERTEX] = top_verts
	top_arrays[Mesh.ARRAY_NORMAL] = top_normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, top_arrays)

	return mesh


## Append one quad (2 triangles) with given corner order v1→v2→v3→v4 and normal n.
## Winding order determines which side the face points toward (CCW = front).
static func _quad(verts: PackedVector3Array, normals: PackedVector3Array,
				  v1: Vector3, v2: Vector3, v3: Vector3, v4: Vector3, n: Vector3) -> void:
	verts.append(v1)
	verts.append(v2)
	verts.append(v3)
	verts.append(v1)
	verts.append(v3)
	verts.append(v4)
	for _i: int in range(6):
		normals.append(n)


# ── Glyph overlay ─────────────────────────────────────────────

static func _add_glyph(root: Node3D, tile: Tile, y: float) -> void:
	var glyph: Label3D = Label3D.new()
	glyph.text = Tile.unicode_char(tile.tile_type)
	glyph.font_size = 96
	glyph.pixel_size = 0.00048
	glyph.position = Vector3(0, y, 0)
	glyph.rotation.x = -PI / 2.0
	glyph.modulate = GLYPH_COLOR
	glyph.outline_size = 0
	root.add_child(glyph)
