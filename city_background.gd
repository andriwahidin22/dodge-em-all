class_name CityBackground
extends BackgroundBase
# Latar kota di Bumi prosedural untuk Dodge 'em All.
# Menyediakan gradien senja/malam kota, siluet gedung bertingkat berlapis parallax,
# jendela menyala yang berkedip pelan, lampu lalu lintas bergerak, kabut tipis malam,
# dan event pesawat/kembang api/kilat awan.

# Sakelar performa untuk perangkat Android menengah / low-end
const ENABLE_CELESTIAL = true
const ENABLE_CITY_PARALLAX = true
const ENABLE_WINDOW_LIGHTS = true
const ENABLE_CITY_EVENTS = true

const MIST_PARTICLE_COUNT = 35
const PARALLAX_SPEEDS = [4.0, 10.0] # kecepatan geser skyline (px/detik)
const THEME_TRANSITION_TIME = 2.0

# Interval event kota (detik)
const EVENT_INTERVAL_MIN = 12.0
const EVENT_INTERVAL_MAX = 25.0
const EVENT_INTERVAL_DANGER_MIN = 7.0
const EVENT_INTERVAL_DANGER_MAX = 14.0

# Palet warna per pita wave (Senja Hangat -> Malam Kota -> Siaga/Badai Merah)
const PALETTES = {
	"calm": {
		"top": Color(0.08, 0.05, 0.12, 1.0),
		"bottom": Color(0.24, 0.10, 0.12, 1.0),
		"skyline_far": Color(0.12, 0.06, 0.10, 0.55),
		"skyline_near": Color(0.06, 0.03, 0.06, 0.75),
		"window_col": Color(1.0, 0.85, 0.45, 0.6)
	},
	"dramatic": {
		"top": Color(0.03, 0.04, 0.10, 1.0),
		"bottom": Color(0.08, 0.08, 0.18, 1.0),
		"skyline_far": Color(0.07, 0.08, 0.16, 0.55),
		"skyline_near": Color(0.03, 0.04, 0.09, 0.75),
		"window_col": Color(0.45, 0.85, 1.0, 0.65)
	},
	"danger": {
		"top": Color(0.06, 0.02, 0.04, 1.0),
		"bottom": Color(0.18, 0.04, 0.06, 1.0),
		"skyline_far": Color(0.12, 0.03, 0.05, 0.60),
		"skyline_near": Color(0.06, 0.01, 0.02, 0.80),
		"window_col": Color(1.0, 0.40, 0.30, 0.7)
	}
}

# Node referensi internal
var _gradient_rect: ColorRect
var _gradient_material: ShaderMaterial
var _celestial_node: Node2D
var _skyline_node: Node2D
var _mist_particles: CPUParticles2D
var _event_node: Node2D

# State warna & transisi
var _current_top: Color = PALETTES["calm"]["top"]
var _current_bottom: Color = PALETTES["calm"]["bottom"]
var _current_skyline_far: Color = PALETTES["calm"]["skyline_far"]
var _current_skyline_near: Color = PALETTES["calm"]["skyline_near"]
var _current_window_col: Color = PALETTES["calm"]["window_col"]
var _theme_tween: Tween

# State parallax & lampu
var _skyline_offset_far = 0.0
var _skyline_offset_near = 0.0
var _traffic_offset = 0.0
var _anim_time = 0.0

# State event visual kota
var _event_timer = 15.0
var _current_event = "none" # "none", "airplane", "distant_lightning", "distant_fireworks", "hot_air_balloon"
var _event_progress = 0.0
var _event_duration = 1.0
var _event_data = {}


func _ready() -> void:
	super._ready()
	_build_gradient_layer()
	_build_celestial_layer()
	_build_skyline_layer()
	_build_mist_particles()
	_build_event_layer()

	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()
	_reset_event_timer()


func _process(delta: float) -> void:
	_anim_time += delta
	_skyline_offset_far += PARALLAX_SPEEDS[0] * delta
	_skyline_offset_near += PARALLAX_SPEEDS[1] * delta
	_traffic_offset += 24.0 * delta

	if _skyline_node:
		_skyline_node.queue_redraw()

	if is_round_active and ENABLE_CITY_EVENTS:
		_update_city_events(delta)


func _on_viewport_size_changed() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	if _gradient_rect:
		_gradient_rect.size = vp_size
	if _mist_particles:
		_mist_particles.position = vp_size * 0.5
		_mist_particles.emission_rect_extents = vp_size * 0.5


# ---------------- Transisi Tema Warna Wave ----------------

func set_wave_theme(wave_num: int) -> void:
	current_wave = wave_num
	var key = "calm"
	if wave_num >= 8:
		key = "danger"
	elif wave_num >= 4:
		key = "dramatic"

	_apply_palette(PALETTES[key], THEME_TRANSITION_TIME)


func reset_to_title_theme() -> void:
	super.reset_to_title_theme()
	_apply_palette(PALETTES["calm"], THEME_TRANSITION_TIME)


func _apply_palette(target: Dictionary, duration: float) -> void:
	if _theme_tween:
		_theme_tween.kill()

	_theme_tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	var s_top = _current_top
	var s_bottom = _current_bottom
	var s_far = _current_skyline_far
	var s_near = _current_skyline_near
	var s_win = _current_window_col

	_theme_tween.tween_method(func(val):
		_current_top = val
		if _gradient_material:
			_gradient_material.set_shader_parameter("top_color", val)
	, s_top, target["top"], duration)

	_theme_tween.tween_method(func(val):
		_current_bottom = val
		if _gradient_material:
			_gradient_material.set_shader_parameter("bottom_color", val)
	, s_bottom, target["bottom"], duration)

	_theme_tween.tween_method(func(val):
		_current_skyline_far = val
	, s_far, target["skyline_far"], duration)

	_theme_tween.tween_method(func(val):
		_current_skyline_near = val
	, s_near, target["skyline_near"], duration)

	_theme_tween.tween_method(func(val):
		_current_window_col = val
	, s_win, target["window_col"], duration)


# ---------------- Event Kota Prosedural ----------------

func start_events() -> void:
	super.start_events()
	_reset_event_timer()


func stop_events() -> void:
	super.stop_events()
	_current_event = "none"
	if _event_node:
		_event_node.queue_redraw()


func activate() -> void:
	super.activate()
	if is_instance_valid(_mist_particles):
		_mist_particles.emitting = true


func deactivate() -> void:
	super.deactivate()
	if is_instance_valid(_mist_particles):
		_mist_particles.emitting = false
	if _theme_tween:
		_theme_tween.kill()


func _reset_event_timer() -> void:
	var min_i = EVENT_INTERVAL_DANGER_MIN if current_wave >= 8 else EVENT_INTERVAL_MIN
	var max_i = EVENT_INTERVAL_DANGER_MAX if current_wave >= 8 else EVENT_INTERVAL_MAX
	_event_timer = randf_range(min_i, max_i)


func _update_city_events(delta: float) -> void:
	if _current_event == "none":
		_event_timer -= delta
		if _event_timer <= 0:
			_spawn_random_event()
	else:
		_event_progress += delta / _event_duration
		if _event_node:
			_event_node.queue_redraw()
		if _event_progress >= 1.0:
			_current_event = "none"
			_reset_event_timer()
			if _event_node:
				_event_node.queue_redraw()


func _spawn_random_event() -> void:
	var vp = get_viewport().get_visible_rect().size
	var pool = ["airplane", "distant_lightning", "distant_fireworks", "hot_air_balloon"]

	_current_event = pool[randi() % pool.size()]
	_event_progress = 0.0

	match _current_event:
		"airplane":
			_event_duration = 4.0
			_event_data = {
				"y": randf_range(50, vp.y * 0.25),
				"start_x": -40.0,
				"end_x": vp.x + 40.0
			}
		"distant_lightning":
			_event_duration = 0.6
			_event_data = {
				"x": randf_range(vp.x * 0.2, vp.x * 0.8),
				"y": randf_range(80, vp.y * 0.3)
			}
		"distant_fireworks":
			_event_duration = 2.0
			_event_data = {
				"pos": Vector2(randf_range(60, vp.x - 60), randf_range(vp.y * 0.25, vp.y * 0.45)),
				"color": Color(randf_range(0.6, 1.0), randf_range(0.6, 1.0), randf_range(0.3, 1.0), 1.0)
			}
		"hot_air_balloon":
			_event_duration = 6.0
			_event_data = {
				"start_pos": Vector2(randf_range(40, vp.x * 0.5), vp.y * 0.55),
				"end_pos": Vector2(randf_range(vp.x * 0.5, vp.x - 40), vp.y * 0.2)
			}


# ---------------- Konstruksi Layer Prosedural ----------------

func _build_gradient_layer() -> void:
	_gradient_rect = ColorRect.new()
	_gradient_rect.name = "SkyGradient"
	_gradient_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	render_mode unshaded;

	uniform vec4 top_color : source_color = vec4(0.08, 0.05, 0.12, 1.0);
	uniform vec4 bottom_color : source_color = vec4(0.24, 0.10, 0.12, 1.0);

	void fragment() {
		COLOR = mix(top_color, bottom_color, UV.y);
	}
	"""
	_gradient_material = ShaderMaterial.new()
	_gradient_material.shader = shader
	_gradient_material.set_shader_parameter("top_color", _current_top)
	_gradient_material.set_shader_parameter("bottom_color", _current_bottom)
	_gradient_rect.material = _gradient_material
	add_child(_gradient_rect)


func _build_celestial_layer() -> void:
	if not ENABLE_CELESTIAL:
		return

	_celestial_node = Node2D.new()
	_celestial_node.name = "CityMoonStars"
	_celestial_node.draw.connect(_on_draw_celestial)
	add_child(_celestial_node)


func _on_draw_celestial() -> void:
	# Bulan sabit kota
	var moon_pos = Vector2(380, 100)
	_celestial_node.draw_circle(moon_pos, 22.0, Color(0.95, 0.92, 0.82, 0.65))
	_celestial_node.draw_circle(moon_pos + Vector2(6, -4), 18.0, _current_top) # bayangan sabit


func _build_skyline_layer() -> void:
	if not ENABLE_CITY_PARALLAX:
		return

	_skyline_node = Node2D.new()
	_skyline_node.name = "SkylineLayer"
	_skyline_node.draw.connect(_on_draw_skyline)
	add_child(_skyline_node)


func _on_draw_skyline() -> void:
	var vp = get_viewport().get_visible_rect().size
	var base_y = vp.y

	# Skyline Jauh
	_draw_building_layer(_skyline_offset_far, base_y - 200.0, 36.0, 65.0, _current_skyline_far, false, vp.x, base_y)

	# Skyline Dekat + Jendela
	_draw_building_layer(_skyline_offset_near, base_y - 120.0, 48.0, 90.0, _current_skyline_near, true, vp.x, base_y)

	# Lampu lalu lintas jalan raya di dasar
	_draw_traffic(vp.x, base_y)


func _draw_building_layer(offset_x: float, min_y: float, b_width: float, b_height: float, col: Color, with_windows: bool, width: float, bottom_y: float) -> void:
	var total_w = width + b_width * 2
	var start_idx = int(floor(offset_x / b_width))
	var count = int(ceil(total_w / b_width)) + 2

	for i in range(count):
		var idx = start_idx + i
		# Pseudorandom deterministik tinggi gedung berdasarkan index
		var pseudo_h = fmod(abs(sin(idx * 12.9898 + 78.233)) * 43758.5453, 1.0)
		var h = b_height + pseudo_h * 70.0
		var x = (idx * b_width) - offset_x
		var y = bottom_y - h

		var rect = Rect2(x, y, b_width - 2.0, h)
		_skyline_node.draw_rect(rect, col)

		# Jendela menyala jika enabled
		if with_windows and ENABLE_WINDOW_LIGHTS and h > 50.0:
			var win_cols = 2
			var win_rows = int(h / 16.0) - 1
			for r in range(win_rows):
				for c in range(win_cols):
					var win_seed = sin(idx * 7.1 + r * 3.3 + c * 1.9)
					if win_seed > 0.15:
						var flicker = sin(_anim_time * 2.0 + idx + r) * 0.15 + 0.85
						var win_col = Color(_current_window_col.r, _current_window_col.g, _current_window_col.b, _current_window_col.a * flicker)
						var wx = x + 8.0 + c * 16.0
						var wy = y + 12.0 + r * 14.0
						_skyline_node.draw_rect(Rect2(wx, wy, 6.0, 6.0), win_col)


func _draw_traffic(width: float, bottom_y: float) -> void:
	var road_y = bottom_y - 8.0
	var car_count = 8
	var spacing = width / float(car_count)

	for c in range(car_count):
		var x = fmod(_traffic_offset + c * spacing, width)
		# Lampu depan putih kekuningan, lampu belakang merah
		_skyline_node.draw_circle(Vector2(x, road_y), 1.8, Color(1.0, 0.95, 0.7, 0.6))
		_skyline_node.draw_circle(Vector2(width - x, road_y + 3.0), 1.6, Color(1.0, 0.25, 0.2, 0.6))


func _build_mist_particles() -> void:
	var dot_tex = _generate_soft_dot_texture(4)
	_mist_particles = CPUParticles2D.new()
	_mist_particles.name = "MistParticles"
	_mist_particles.texture = dot_tex
	_mist_particles.amount = MIST_PARTICLE_COUNT
	_mist_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_mist_particles.direction = Vector2(1, 0.3)
	_mist_particles.spread = 35.0
	_mist_particles.gravity = Vector2(2.0, 1.0)
	_mist_particles.initial_velocity_min = 6.0
	_mist_particles.initial_velocity_max = 18.0
	_mist_particles.scale_amount_min = 0.8
	_mist_particles.scale_amount_max = 2.0
	_mist_particles.color = Color(0.7, 0.75, 0.85, 0.25)
	_mist_particles.lifetime = 10.0
	_mist_particles.preprocess = 8.0
	add_child(_mist_particles)


func _build_event_layer() -> void:
	_event_node = Node2D.new()
	_event_node.name = "CityEventLayer"
	_event_node.draw.connect(_on_draw_event)
	add_child(_event_node)


func _on_draw_event() -> void:
	if _current_event == "none":
		return

	var vp = get_viewport().get_visible_rect().size

	match _current_event:
		"airplane":
			var cur_x = lerp(_event_data.start_x, _event_data.end_x, _event_progress)
			var y = _event_data.y
			# Lampu navigasi pesawat (putih + merah berkedip cepat)
			_event_node.draw_circle(Vector2(cur_x, y), 2.2, Color(1.0, 1.0, 1.0, 0.8))
			if fmod(_event_progress * 12.0, 1.0) < 0.4:
				_event_node.draw_circle(Vector2(cur_x - 6, y + 2), 2.0, Color(1.0, 0.2, 0.2, 0.9))

		"distant_lightning":
			var x = _event_data.x
			var y = _event_data.y
			var alpha = sin(_event_progress * PI) * 0.35
			_event_node.draw_circle(Vector2(x, y), 80.0, Color(0.85, 0.85, 1.0, alpha * 0.4))

		"distant_fireworks":
			var pos = _event_data.pos
			var col = _event_data.color
			var alpha = sin(_event_progress * PI) * 0.7
			var radius = 25.0 * _event_progress
			for i in range(8):
				var angle = i * (TAU / 8.0)
				var spark = pos + Vector2(cos(angle), sin(angle)) * radius
				_event_node.draw_circle(spark, 1.8, Color(col.r, col.g, col.b, alpha))

		"hot_air_balloon":
			var pos = _event_data.start_pos.lerp(_event_data.end_pos, _event_progress)
			var alpha = sin(_event_progress * PI) * 0.45
			# Balon udara siluet lonjong
			_event_node.draw_circle(pos, 8.0, Color(0.12, 0.08, 0.12, alpha))
			_event_node.draw_rect(Rect2(pos.x - 2, pos.y + 10, 4, 3), Color(0.2, 0.15, 0.1, alpha))


func _generate_soft_dot_texture(radius: int) -> ImageTexture:
	var diameter = radius * 2
	var img = Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var center = Vector2(radius, radius)
	for y in range(diameter):
		for x in range(diameter):
			var dist = center.distance_to(Vector2(x + 0.5, y + 0.5))
			var a = clamp(1.0 - (dist / float(radius)), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
