## game_hud.gd — In-game HUD overlay.
##
## Shows scores, shanten count, waiting tiles, call action buttons,
## round results, and game over screen.
extends Control


# ── Node references (set in _ready via get_node) ──────────────

var score_label: Label = null
var shanten_label: Label = null
var waits_label: Label = null
var round_info_label: Label = null
var tiles_left_label: Label = null

var call_buttons_container: HBoxContainer = null
var btn_tsumo: Button = null
var btn_ron: Button = null
var btn_pon: Button = null
var btn_chii: Button = null
var btn_kan: Button = null
var btn_riichi: Button = null
var btn_skip: Button = null

var result_panel: PanelContainer = null
var result_label: Label = null
var result_scores_label: Label = null
var btn_next_round: Button = null

var tooltip_label: Label = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Full-screen overlay (doesn't block 3D input — mouse_filter set to IGNORE on containers)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# ── Top bar: round info + tiles left ──
	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 30
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)

	round_info_label = _make_label("East 1", 16)
	round_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(round_info_label)

	tiles_left_label = _make_label("Tiles: 122", 16)
	tiles_left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tiles_left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(tiles_left_label)

	# ── Score display (4 corners) ──
	score_label = _make_label("", 14)
	score_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	score_label.offset_left = 10
	score_label.offset_top = 35
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(score_label)

	# ── Bottom-left: shanten + waits ──
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	info_vbox.offset_left = 10
	info_vbox.offset_bottom = -80
	info_vbox.offset_top = -130
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info_vbox)

	shanten_label = _make_label("Shanten: -", 18)
	info_vbox.add_child(shanten_label)

	waits_label = _make_label("", 16)
	waits_label.modulate = Color(0.5, 1.0, 0.5)
	info_vbox.add_child(waits_label)

	# ── Bottom-center: call buttons ──
	call_buttons_container = HBoxContainer.new()
	call_buttons_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	call_buttons_container.offset_top = -60
	call_buttons_container.offset_bottom = -20
	call_buttons_container.offset_left = -200
	call_buttons_container.offset_right = 200
	call_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	call_buttons_container.add_theme_constant_override("separation", 8)
	call_buttons_container.visible = false
	add_child(call_buttons_container)

	btn_tsumo = _make_call_button("Tsumo", "tsumo", Color(1.0, 0.85, 0.0))
	btn_ron = _make_call_button("Ron", "ron", Color(1.0, 0.3, 0.3))
	btn_pon = _make_call_button("Pon", "pon", Color(0.3, 0.7, 1.0))
	btn_chii = _make_call_button("Chii", "chii", Color(0.3, 1.0, 0.5))
	btn_kan = _make_call_button("Kan", "kan", Color(0.8, 0.5, 1.0))
	btn_riichi = _make_call_button("Riichi", "riichi", Color(1.0, 0.6, 0.1))
	btn_skip = _make_call_button("Skip", "skip", Color(0.5, 0.5, 0.5))

	# ── Hover tooltip (positioned dynamically near cursor) ──
	tooltip_label = Label.new()
	tooltip_label.add_theme_font_size_override("font_size", 18)
	tooltip_label.add_theme_color_override("font_color", Color.WHITE)
	tooltip_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	tooltip_label.add_theme_constant_override("shadow_offset_x", 2)
	tooltip_label.add_theme_constant_override("shadow_offset_y", 2)
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_label.visible = false

	var tooltip_style: StyleBoxFlat = StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.1, 0.12, 0.18, 0.9)
	tooltip_style.corner_radius_top_left = 4
	tooltip_style.corner_radius_top_right = 4
	tooltip_style.corner_radius_bottom_left = 4
	tooltip_style.corner_radius_bottom_right = 4
	tooltip_style.content_margin_left = 8
	tooltip_style.content_margin_right = 8
	tooltip_style.content_margin_top = 4
	tooltip_style.content_margin_bottom = 4
	tooltip_label.add_theme_stylebox_override("normal", tooltip_style)
	add_child(tooltip_label)

	# ── Center: result panel (hidden) ──
	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -180
	result_panel.offset_right = 180
	result_panel.offset_top = -100
	result_panel.offset_bottom = 100
	result_panel.visible = false

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.12, 0.18, 0.95)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	result_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(result_panel)

	var result_vbox: VBoxContainer = VBoxContainer.new()
	result_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	result_vbox.add_theme_constant_override("separation", 12)
	result_panel.add_child(result_vbox)

	result_label = _make_label("", 28)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_vbox.add_child(result_label)

	result_scores_label = _make_label("", 16)
	result_scores_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_vbox.add_child(result_scores_label)

	btn_next_round = Button.new()
	btn_next_round.text = "Next Round"
	btn_next_round.custom_minimum_size = Vector2(140, 36)
	btn_next_round.pressed.connect(_on_next_round_pressed)
	result_vbox.add_child(btn_next_round)


# ── Public API ─────────────────────────────────────────────────

func update_info(scores: Array, shanten: int, waits: String, wind: String, round_num: int, tiles_remaining: int) -> void:
	# Scores
	var score_text: String = ""
	var names: Array = ["You", "Right", "Across", "Left"]
	for i: int in range(4):
		score_text += names[i] + ": " + str(scores[i]) + "\n"
	score_label.text = score_text

	# Shanten
	if shanten == 0:
		shanten_label.text = "TENPAI"
		shanten_label.modulate = Color(1.0, 0.85, 0.0)
	elif shanten == 1:
		shanten_label.text = "Iishanten (1 away)"
		shanten_label.modulate = Color(0.7, 0.8, 1.0)
	else:
		shanten_label.text = "Shanten: " + str(shanten)
		shanten_label.modulate = Color.WHITE

	# Waits
	if waits.length() > 0:
		waits_label.text = "Waiting: " + waits
		waits_label.visible = true
	else:
		waits_label.visible = false

	# Round info
	var round_in_wind: int = (round_num % 4) + 1
	round_info_label.text = wind + " " + str(round_in_wind)

	# Tiles left
	tiles_left_label.text = "Tiles: " + str(tiles_remaining)


func show_call_buttons(calls: Dictionary) -> void:
	_update_call_button(btn_tsumo, "Tsumo", calls.get(&"tsumo"))
	_update_call_button(btn_ron, "Ron", calls.get(&"ron"))
	_update_call_button(btn_pon, "Pon", calls.get(&"pon"))
	_update_call_button(btn_chii, "Chii", calls.get(&"chii"))
	_update_call_button(btn_kan, "Kan", calls.get(&"kan"))
	_update_call_button(btn_riichi, "Riichi", calls.get(&"riichi"))
	btn_skip.visible = true
	call_buttons_container.visible = true


func _update_call_button(btn: Button, default_label: String, value: Variant) -> void:
	if value == null or (value is bool and not value):
		btn.visible = false
		return
	btn.visible = true
	if value is String:
		btn.text = value
	else:
		btn.text = default_label


func hide_call_buttons() -> void:
	call_buttons_container.visible = false


func show_tile_tooltip(text: String, screen_pos: Vector2) -> void:
	tooltip_label.text = text
	tooltip_label.visible = true
	# Position slightly above-right of the cursor, keeping on screen
	var offset: Vector2 = Vector2(16, -40)
	tooltip_label.position = screen_pos + offset


func hide_tile_tooltip() -> void:
	tooltip_label.visible = false


func show_round_result(result_text: String, scores: Array) -> void:
	result_label.text = result_text
	var names: Array = ["You", "Right", "Across", "Left"]
	var lines: Array = []
	for i: int in range(4):
		lines.append(names[i] + ": " + str(scores[i]))
	result_scores_label.text = "\n".join(lines)
	btn_next_round.text = "Next Round"
	result_panel.visible = true


func show_game_over(scores: Array) -> void:
	result_label.text = "Game Over"
	var names: Array = ["You", "Right", "Across", "Left"]
	var lines: Array = []
	for i: int in range(4):
		lines.append(names[i] + ": " + str(scores[i]))
	result_scores_label.text = "\n".join(lines)
	btn_next_round.text = "Main Menu"
	result_panel.visible = true


# ── Private helpers ────────────────────────────────────────────

func _make_label(text: String, size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_call_button(text: String, call_type: String, color: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(80, 36)
	btn.visible = false

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color.darkened(0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style)

	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = color.darkened(0.1)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style: StyleBoxFlat = style.duplicate()
	pressed_style.bg_color = color
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.pressed.connect(func() -> void: _on_call_pressed(call_type))
	call_buttons_container.add_child(btn)
	return btn


func _on_call_pressed(call_type: String) -> void:
	var parent_controller: Node = get_parent()
	if parent_controller.has_method("_on_call_button_pressed"):
		parent_controller._on_call_button_pressed(call_type)


func _on_next_round_pressed() -> void:
	result_panel.visible = false
	var parent_controller: Node = get_parent()
	if parent_controller.has_method("_on_next_round_pressed"):
		parent_controller._on_next_round_pressed()
