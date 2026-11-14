extends ColorRect
# Layar Credits: kartu-kartu teks kredit film semi-transparan di atas latar permainan.
# Menyediakan pemilih 4 tema visual & suara (Angkasa, Planet, Laut, Kota)
# serta slider pengaturan volume Musik dan Suara Latar (Ambience).

signal finished
signal theme_changed_requested(theme_id: String)
signal volume_changed_requested(bus_name: String, linear_vol: float)

const SpaceTheme = preload("res://space_theme.gd")
const FONT_RES = preload("res://fonts/Xolonium-Regular.ttf")

@export var fade_in_time = 1.0
@export var hold_time = 2.5
@export var fade_out_time = 1.0

const THEME_DATA = [
	{"id": "space", "name": "Angkasa"},
	{"id": "planet", "name": "Planet"},
	{"id": "ocean", "name": "Laut"},
	{"id": "city", "name": "Kota"}
]

const CARDS = [
	{
		"title": "Dodge 'em All",
		"body": "Tugas Pemrograman Game\nUNAS · 2026"
	},
	{
		"title": "Kelompok",
		"body": "[Kelompok 1]"
	},
	{
		"title": "Anggota & Peran",
		"body": "[Andri Wahidin (26316625027)]\n\n[Arshika Septia Ramadhani (25306622001)]\n\n[Jaka Ramdani (26316625052)]\n"
	},
	{
		"title": "Berdasarkan Demo",
		"body": "Dodge the Creeps\ndemo resmi Godot Engine\n(godotengine/godot-demo-projects)\n© 2017 KidsCanCode · Lisensi MIT"
	},
	{
		"title": "Game Engine",
		"body": "Godot Engine 4.7"
	},
	{
		"title": "Karakter & Musuh",
		"body": "Kenney Platformer Pack Redux\n&\nPlatformer Art More Animations & Enemies\n(CC0)"
	},
	{
		"title": "Ikon & Antarmuka",
		"body": "Kenney Game Icons & UI Pack (CC0)\n\n25x25 Hearts oleh Min (CC0)"
	},
	{
		"title": "Font",
		"body": "Xolonium oleh Severin Meyer\nSIL Open Font License 1.1"
	},
	{
		"title": "Musik Permainan",
		"body": "Musik bawaan: \"House In a Forest Loop\"\noleh HorrorPen (CC-BY 3.0)\n\nMusik tema: sintetis prosedural arcade (CC0)\nbuatan sendiri via generator Python"
	},
	{
		"title": "Audio Wave",
		"body": "Efek suara sintetis (CC0)\nPlaceholder buatan sendiri via generator"
	},
	{
		"title": "Suara Latar (Ambience)",
		"body": "Ambience loop sintetis (CC0)\nPlaceholder buatan sendiri via generator Python"
	},
	{
		"title": "Terima Kasih",
		"body": "telah memainkan\nDodge 'em All!"
	},
]

var _index = -1
var _tween: Tween
var _current_theme_id = "space"

# Kontrol UI dinamis
var _card_panel: Panel
var _btn_close: Button
var _controls_container: VBoxContainer
var _theme_buttons: Dictionary = {}
var _slider_music: HSlider
var _slider_ambience: HSlider
var _is_updating_sliders = false


func _ready() -> void:
	color = Color(0, 0, 0, 0.28) # Scrim tipis agar latar di belakang terlihat jelas
	_setup_card_style()
	_setup_close_button()
	_setup_bottom_controls()


func _setup_card_style() -> void:
	# Panel semi-transparan di belakang teks kartu agar selalu terbaca tajam
	_card_panel = Panel.new()
	_card_panel.name = "CardBackdrop"
	_card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_panel.offset_left = 24.0
	_card_panel.offset_right = -24.0
	_card_panel.offset_top = 130.0
	_card_panel.offset_bottom = -160.0

	var card_sb = SpaceTheme.create_card_style()
	card_sb.bg_color = Color(0.04, 0.06, 0.12, 0.72)
	card_sb.border_color = Color(0.15, 0.88, 0.95, 0.4)
	card_sb.set_border_width_all(1)
	_card_panel.add_theme_stylebox_override("panel", card_sb)
	$Card.add_child(_card_panel)
	$Card.move_child(_card_panel, 0)

	# Styling teks kartu
	$Card/Title.add_theme_color_override("font_color", SpaceTheme.COLOR_GOLD)
	$Card/Title.add_theme_color_override("font_outline_color", SpaceTheme.COLOR_TEXT_OUTLINE)
	$Card/Title.add_theme_constant_override("outline_size", 4)

	$Card/Body.add_theme_color_override("font_color", SpaceTheme.COLOR_TEXT_PRIMARY)
	$Card/Body.add_theme_color_override("font_outline_color", SpaceTheme.COLOR_TEXT_OUTLINE)
	$Card/Body.add_theme_constant_override("outline_size", 3)


func _setup_close_button() -> void:
	_btn_close = Button.new()
	_btn_close.name = "CloseCreditsButton"
	_btn_close.text = "✕ Tutup"
	_btn_close.custom_minimum_size = Vector2(96, 42)
	_btn_close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_btn_close.offset_left = -116.0
	_btn_close.offset_right = -20.0
	_btn_close.offset_top = 24.0
	_btn_close.offset_bottom = 66.0
	_btn_close.add_theme_font_override("font", FONT_RES)
	_btn_close.add_theme_font_size_override("font_size", 16)

	var sb_norm = SpaceTheme.create_button_style(Color(0.08, 0.12, 0.22, 0.85), Color(0.3, 0.5, 0.7, 0.6), 10, 1)
	var sb_hov = SpaceTheme.create_button_style(Color(0.15, 0.22, 0.38, 0.95), SpaceTheme.COLOR_ACCENT_CYAN, 10, 2)
	_btn_close.add_theme_stylebox_override("normal", sb_norm)
	_btn_close.add_theme_stylebox_override("hover", sb_hov)
	_btn_close.add_theme_stylebox_override("pressed", sb_hov)
	_btn_close.add_theme_color_override("font_color", SpaceTheme.COLOR_TEXT_PRIMARY)
	_btn_close.pressed.connect(skip)
	add_child(_btn_close)


func _setup_bottom_controls() -> void:
	_controls_container = VBoxContainer.new()
	_controls_container.name = "BottomControls"
	_controls_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_controls_container.offset_left = 16.0
	_controls_container.offset_right = -16.0
	_controls_container.offset_top = -148.0
	_controls_container.offset_bottom = -46.0
	_controls_container.add_theme_constant_override("separation", 8)
	_controls_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_controls_container)

	# --- Baris Slider Volume (Musik & Suara Latar) ---
	var vol_box = HBoxContainer.new()
	vol_box.name = "VolumeSliders"
	vol_box.add_theme_constant_override("separation", 10)
	vol_box.mouse_filter = Control.MOUSE_FILTER_STOP

	# Slider Musik
	var lbl_music = Label.new()
	lbl_music.text = "Musik:"
	lbl_music.add_theme_font_override("font", FONT_RES)
	lbl_music.add_theme_font_size_override("font_size", 14)
	lbl_music.add_theme_color_override("font_color", SpaceTheme.COLOR_TEXT_MUTED)
	vol_box.add_child(lbl_music)

	_slider_music = HSlider.new()
	_slider_music.name = "MusicSlider"
	_slider_music.min_value = 0.0
	_slider_music.max_value = 1.0
	_slider_music.step = 0.05
	_slider_music.value = 0.8
	_slider_music.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider_music.custom_minimum_size = Vector2(80, 24)
	_slider_music.mouse_filter = Control.MOUSE_FILTER_STOP
	_slider_music.value_changed.connect(_on_music_slider_changed)
	vol_box.add_child(_slider_music)

	# Separator tengah
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(10, 0)
	vol_box.add_child(spacer)

	# Slider Suara Latar (Ambience)
	var lbl_ambience = Label.new()
	lbl_ambience.text = "Suara Latar:"
	lbl_ambience.add_theme_font_override("font", FONT_RES)
	lbl_ambience.add_theme_font_size_override("font_size", 14)
	lbl_ambience.add_theme_color_override("font_color", SpaceTheme.COLOR_TEXT_MUTED)
	vol_box.add_child(lbl_ambience)

	_slider_ambience = HSlider.new()
	_slider_ambience.name = "AmbienceSlider"
	_slider_ambience.min_value = 0.0
	_slider_ambience.max_value = 1.0
	_slider_ambience.step = 0.05
	_slider_ambience.value = 0.5
	_slider_ambience.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider_ambience.custom_minimum_size = Vector2(80, 24)
	_slider_ambience.mouse_filter = Control.MOUSE_FILTER_STOP
	_slider_ambience.value_changed.connect(_on_ambience_slider_changed)
	vol_box.add_child(_slider_ambience)

	_controls_container.add_child(vol_box)

	# --- Baris 4 Tombol Tema ---
	var theme_box = HBoxContainer.new()
	theme_box.name = "ThemeButtons"
	theme_box.add_theme_constant_override("separation", 8)
	theme_box.mouse_filter = Control.MOUSE_FILTER_STOP

	for t in THEME_DATA:
		var btn = Button.new()
		btn.name = "BtnTheme_" + t.id
		btn.text = t.name
		btn.custom_minimum_size = Vector2(0, 52)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_override("font", FONT_RES)
		btn.add_theme_font_size_override("font_size", 16)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var theme_id = t.id
		btn.pressed.connect(func(): _on_theme_button_pressed(theme_id))
		theme_box.add_child(btn)
		_theme_buttons[theme_id] = btn

	_controls_container.add_child(theme_box)


# ---------------- Handler Event & Nilai UI ----------------

func _on_music_slider_changed(value: float) -> void:
	if _is_updating_sliders:
		return
	volume_changed_requested.emit("Music", value)


func _on_ambience_slider_changed(value: float) -> void:
	if _is_updating_sliders:
		return
	volume_changed_requested.emit("Ambience", value)


func _on_theme_button_pressed(theme_id: String) -> void:
	_current_theme_id = theme_id
	_update_theme_buttons_visual(theme_id)
	theme_changed_requested.emit(theme_id)


func _update_theme_buttons_visual(active_id: String) -> void:
	for id in _theme_buttons.keys():
		var btn = _theme_buttons[id] as Button
		var is_active = (id == active_id)
		var bg_col = Color(0.12, 0.22, 0.38, 0.95) if is_active else Color(0.06, 0.09, 0.16, 0.85)
		var border_col = SpaceTheme.COLOR_GOLD if is_active else Color(0.20, 0.35, 0.48, 0.5)
		var border_w = 3 if is_active else 1

		var sb = SpaceTheme.create_button_style(bg_col, border_col, 10, border_w)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("focus", sb)
		btn.add_theme_color_override("font_color", SpaceTheme.COLOR_GOLD if is_active else SpaceTheme.COLOR_TEXT_PRIMARY)
		btn.add_theme_color_override("font_outline_color", SpaceTheme.COLOR_TEXT_OUTLINE)
		btn.add_theme_constant_override("outline_size", 2)


# Memulai tampilan credit dari kartu pertama
func play() -> void:
	_index = -1
	show()

	# Sinkronkan nilai slider dari SaveManager
	_is_updating_sliders = true
	var saved_music = SaveManager.get_setting("music_volume", 0.8)
	var saved_amb = SaveManager.get_setting("ambience_volume", 0.7)
	var saved_theme = SaveManager.get_setting("background_theme", "space")
	if saved_amb == null or saved_amb <= 0.001:
		saved_amb = 0.7
	if saved_music == null or saved_music <= 0.001:
		saved_music = 0.8
	if _slider_music:
		_slider_music.value = saved_music
	if _slider_ambience:
		_slider_ambience.value = saved_amb
	_is_updating_sliders = false

	_current_theme_id = saved_theme
	_update_theme_buttons_visual(saved_theme)

	_next_card()


# Berhenti di tengah jalan (pemain mengetuk layar di luar kontrol, tombol tutup, Esc, atau Back)
func skip() -> void:
	if visible:
		_finish()


func _next_card() -> void:
	_index += 1
	if _index >= CARDS.size():
		_finish()
		return
	$Card/Title.text = CARDS[_index].title
	$Card/Body.text = CARDS[_index].body
	$Card.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property($Card, "modulate:a", 1.0, fade_in_time)
	_tween.tween_interval(hold_time)
	_tween.tween_property($Card, "modulate:a", 0.0, fade_out_time)
	_tween.tween_callback(_next_card)


func _finish() -> void:
	if _tween:
		_tween.kill()
	hide()
	finished.emit()


# Ketukan di luar area kontrol menutup layar credit
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		var pos = event.position
		if _is_point_inside_control(_controls_container, pos) or _is_point_inside_control(_btn_close, pos):
			return # Ketukan pada tombol atau slider jangan menutup credit
		accept_event()
		skip()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Navigasi keyboard kiri / kanan untuk berganti tema
	if event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"move_right"):
		_cycle_theme(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"move_left"):
		_cycle_theme(-1)
		get_viewport().set_input_as_handled()


func _cycle_theme(direction: int) -> void:
	var cur_idx = 0
	for i in range(THEME_DATA.size()):
		if THEME_DATA[i].id == _current_theme_id:
			cur_idx = i
			break
	var next_idx = (cur_idx + direction + THEME_DATA.size()) % THEME_DATA.size()
	var next_id = THEME_DATA[next_idx].id
	_on_theme_button_pressed(next_id)


func _is_point_inside_control(ctrl: Control, point: Vector2) -> bool:
	if not is_instance_valid(ctrl) or not ctrl.is_visible_in_tree():
		return false
	return ctrl.get_global_rect().has_point(point)
