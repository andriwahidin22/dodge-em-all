class_name PlanetBackground
extends BackgroundBase
# Latar planet asing prosedural untuk Dodge 'em All.
# Menyediakan gradien langit berdebu, kabut atmosferik, planet raksasa bercincin,
# pegunungan/kawah siluet berlapis parallax, partikel spora melayang, dan event badai/meteor.

# Sakelar performa untuk perangkat Android menengah / low-end
const ENABLE_ATMOSPHERE_HAZE = true
const ENABLE_CELESTIAL_BODIES = true
const ENABLE_PARALLAX_RIDGES = true
const ENABLE_PLANET_EVENTS = true

const DUST_PARTICLE_COUNT = 40
const PARALLAX_SPEEDS = [6.0, 14.0] # kecepatan geser pegunungan (px/detik)
const THEME_TRANSITION_TIME = 2.0

# Interval event planet (detik)
const EVENT_INTERVAL_MIN = 12.0
const EVENT_INTERVAL_MAX = 25.0
const EVENT_INTERVAL_DANGER_MIN = 7.0
const EVENT_INTERVAL_DANGER_MAX = 14.0

# Palet warna per pita wave
const PALETTES = {
	"calm": {
		"top": Color(0.06, 0.03, 0.05, 1.0),
		"bottom": Color(0.18, 0.08, 0.06, 1.0),
		"haze": Color(0.24, 0.12, 0.06, 0.14),
		"ridge_far": Color(0.10, 0.05, 0.06, 0.45),
		"ridge_near": Color(0.06, 0.02, 0.03, 0.65)
	},
	"dramatic": {
		"top": Color(0.08, 0.02, 0.07, 1.0),
		"bottom": Color(0.22, 0.06, 0.12, 1.0),
		"haze": Color(0.28, 0.08, 0.15, 0.18),
		"ridge_far": Color(0.12, 0.03, 0.07, 0.50),
		"ridge_near": Color(0.07, 0.01, 0.04, 0.70)
	},
	"danger": {
		"top": Color(0.09, 0.01, 0.02, 1.0),
		"bottom": Color(0.25, 0.03, 0.03, 1.0),
		"haze": Color(0.35, 0.05, 0.04, 0.22),
		"ridge_far": Color(0.14, 0.02, 0.02, 0.55),
		"ridge_near": Color(0.08, 0.01, 0.01, 0.75)
	}
}

# Node referensi internal
var _gradient_rect: ColorRect
var _gradient_material: ShaderMaterial
var _haze_rect: ColorRect
var _haze_material: ShaderMaterial
var _dust_particles: CPUParticles2D
var _celestial_node: Node2D
var _ridge_node: Node2D
var _event_node: Node2D

# State warna & transisi
var _current_top: Color = PALETTES["calm"]["top"]
var _current_bottom: Color = PALETTES["calm"]["bottom"]
var _current_haze: Color = PALETTES["calm"]["haze"]
var _current_ridge_far: Color = PALETTES["calm"]["ridge_far"]
var _current_ridge_near: Color = PALETTES["calm"]["ridge_near"]
var _theme_tween: Tween

# State parallax pegunungan & benda langit
var _giant_planet_pos = Vector2(360, 150)
var _moon_pos = Vector2(90, 240)
var _ridge_offset_far = 0.0
var _ridge_offset_near = 0.0

# State event visual planet
var _event_timer = 15.0
var _current_event = "none" # "none", "dust_storm", "atmospheric_meteor", "twin_star", "horizon_lightning"
var _event_progress = 0.0
var _event_duration = 1.0
var _event_data = {}


func _ready() -> void:
	super._ready()
	_build_gradient_layer()
	_build_haze_layer()
	_build_celestial_layer()
	_build_dust_particles()
	_build_ridge_layer()
	_build_event_layer()

	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()
	_reset_event_timer()


func _process(delta: float) -> void:
	# Pergerakan parallax pelan pegunungan
	_ridge_offset_far += PARALLAX_SPEEDS[0] * delta
	_ridge_offset_near += PARALLAX_SPEEDS[1] * delta
	if _ridge_node:
		_ridge_node.queue_redraw()

	# Benda langit bergeser sangat pelan
	_giant_planet_pos.x -= 0.5 * delta
	if _celestial_node:
		_celestial_node.queue_redraw()

	if is_round_active and ENABLE_PLANET_EVENTS:
		_update_planet_events(delta)


func _on_viewport_size_changed() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	if _gradient_rect:
		_gradient_rect.size = vp_size
	if _haze_rect:
		_haze_rect.size = vp_size
	if _dust_particles:
		_dust_particles.position = vp_size * 0.5
		_dust_particles.emission_rect_extents = vp_size * 0.5


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
	var s_haze = _current_haze
	var s_rf = _current_ridge_far
	var s_rn = _current_ridge_near

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

	if _haze_material:
		_theme_tween.tween_method(func(val):
			_current_haze = val
			_haze_material.set_shader_parameter("haze_color", val)
		, s_haze, target["haze"], duration)

	_theme_tween.tween_method(func(val):
		_current_ridge_far = val
	, s_rf, target["ridge_far"], duration)

	_theme_tween.tween_method(func(val):
		_current_ridge_near = val
	, s_rn, target["ridge_near"], duration)


# ---------------- Event Planet Prosedural ----------------

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
	if is_instance_valid(_dust_particles):
		_dust_particles.emitting = true


func deactivate() -> void:
	super.deactivate()
	if is_instance_valid(_dust_particles):
		_dust_particles.emitting = false
	if _theme_tween:
		_theme_tween.kill()


func _reset_event_timer() -> void:
	var min_i = EVENT_INTERVAL_DANGER_MIN if current_wave >= 8 else EVENT_INTERVAL_MIN
	var max_i = EVENT_INTERVAL_DANGER_MAX if current_wave >= 8 else EVENT_INTERVAL_MAX
	_event_timer = randf_range(min_i, max_i)


func _update_planet_events(delta: float) -> void:
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
	var pool = ["dust_storm", "atmospheric_meteor", "twin_star", "horizon_lightning"]
	if current_wave >= 8:
		pool = ["dust_storm", "dust_storm", "atmospheric_meteor", "horizon_lightning"]

	_current_event = pool[randi() % pool.size()]
	_event_progress = 0.0

	match _current_event:
		"dust_storm":
			_event_duration = 3.5
			_event_data = {
				"y_mid": randf_range(vp.y * 0.4, vp.y * 0.8),
				"height": randf_range(160, 260)
			}
		"atmospheric_meteor":
			_event_duration = 1.0
			_event_data = {
				"start": Vector2(randf_range(vp.x * 0.2, vp.x * 0.8), -20),
				"dir": Vector2(randf_range(-0.5, 0.5), 1.0).normalized(),
				"length": randf_range(180, 280)
			}
		"twin_star":
			_event_duration = 2.4
			_event_data = {
				"pos": Vector2(randf_range(60, vp.x - 60), randf_range(50, vp.y * 0.35))
			}
		"horizon_lightning":
			_event_duration = 0.5
			_event_data = {
				"x": randf_range(vp.x * 0.2, vp.x * 0.8),
				"y": vp.y * 0.82
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

	uniform vec4 top_color : source_color = vec4(0.06, 0.03, 0.05, 1.0);
	uniform vec4 bottom_color : source_color = vec4(0.18, 0.08, 0.06, 1.0);

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


func _build_haze_layer() -> void:
	if not ENABLE_ATMOSPHERE_HAZE:
		return

	_haze_rect = ColorRect.new()
	_haze_rect.name = "HazeLayer"
	_haze_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	render_mode unshaded;

	uniform vec4 haze_color : source_color = vec4(0.24, 0.12, 0.06, 0.14);
	uniform float time_speed = 0.04;

	void fragment() {
		vec2 uv = UV;
		float t = TIME * time_speed;
		float wave = sin(uv.x * 4.0 + t) * 0.08 + cos(uv.x * 2.0 - t * 0.7) * 0.05;
		float vertical_fade = smoothstep(0.3, 0.95, uv.y + wave);
		COLOR = vec4(haze_color.rgb, haze_color.a * vertical_fade);
	}
	"""
	_haze_material = ShaderMaterial.new()
	_haze_material.shader = shader
	_haze_material.set_shader_parameter("haze_color", _current_haze)
	_haze_rect.material = _haze_material
	add_child(_haze_rect)


func _build_celestial_layer() -> void:
	if not ENABLE_CELESTIAL_BODIES:
		return

	_celestial_node = Node2D.new()
	_celestial_node.name = "CelestialBodies"
	_celestial_node.draw.connect(_on_draw_celestial)
	add_child(_celestial_node)


func _on_draw_celestial() -> void:
	# Planet raksasa dengan cincin
	var p_rad = 58.0
	_celestial_node.draw_circle(_giant_planet_pos, p_rad, Color(0.22, 0.10, 0.12, 0.50))
	_celestial_node.draw_circle(_giant_planet_pos + Vector2(-6, -6), p_rad * 0.82, Color(0.30, 0.14, 0.16, 0.35))

	# Cincin planet miring
	var ring_col = Color(0.40, 0.22, 0.20, 0.25)
	for r in range(2):
		_celestial_node.draw_arc(_giant_planet_pos, p_rad + 16.0 + r * 6.0, -0.8, 2.3, 36, ring_col, 2.0)

	# Bulan kawah kecil
	var m_rad = 22.0
	_celestial_node.draw_circle(_moon_pos, m_rad, Color(0.18, 0.12, 0.10, 0.45))
	_celestial_node.draw_circle(_moon_pos + Vector2(-4, -3), m_rad * 0.75, Color(0.26, 0.18, 0.15, 0.25))


func _build_dust_particles() -> void:
	var dot_tex = _generate_soft_dot_texture(4)
	_dust_particles = CPUParticles2D.new()
	_dust_particles.name = "DustParticles"
	_dust_particles.texture = dot_tex
	_dust_particles.amount = DUST_PARTICLE_COUNT
	_dust_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust_particles.direction = Vector2(1, 0.2) # Melayang miring pelan
	_dust_particles.spread = 45.0
	_dust_particles.gravity = Vector2(4.0, 2.0)
	_dust_particles.initial_velocity_min = 10.0
	_dust_particles.initial_velocity_max = 24.0
	_dust_particles.scale_amount_min = 0.8
	_dust_particles.scale_amount_max = 1.8
	_dust_particles.color = Color(0.85, 0.65, 0.45, 0.4)

	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 0.8, 0.6, 0.0))
	gradient.add_point(0.2, Color(1, 0.8, 0.6, 0.45))
	gradient.add_point(0.8, Color(1, 0.7, 0.5, 0.35))
	gradient.set_color(1, Color(1, 0.8, 0.6, 0.0))
	_dust_particles.color_ramp = gradient

	_dust_particles.lifetime = 10.0
	_dust_particles.preprocess = 8.0
	add_child(_dust_particles)


func _build_ridge_layer() -> void:
	if not ENABLE_PARALLAX_RIDGES:
		return

	_ridge_node = Node2D.new()
	_ridge_node.name = "ParallaxRidges"
	_ridge_node.draw.connect(_on_draw_ridges)
	add_child(_ridge_node)


func _on_draw_ridges() -> void:
	var vp = get_viewport().get_visible_rect().size
	var base_y = vp.y

	# Lapisan bukit jauh (ridge far)
	_draw_single_ridge(_ridge_offset_far, base_y - 120.0, 75.0, 180.0, _current_ridge_far, vp.x, base_y)

	# Lapisan bukit dekat (ridge near)
	_draw_single_ridge(_ridge_offset_near, base_y - 65.0, 45.0, 130.0, _current_ridge_near, vp.x, base_y)


func _draw_single_ridge(offset_x: float, peak_y: float, amp: float, wave_len: float, col: Color, width: float, bottom_y: float) -> void:
	var pts = PackedVector2Array()
	pts.append(Vector2(0, bottom_y))

	var step = 20.0
	var x = 0.0
	while x <= width + step:
		var sample_x = x + offset_x
		var y = peak_y + sin(sample_x / wave_len * TAU) * amp * 0.7 + cos(sample_x / (wave_len * 0.5) * TAU) * amp * 0.3
		pts.append(Vector2(x, y))
		x += step

	pts.append(Vector2(width, bottom_y))
	_ridge_node.draw_colored_polygon(pts, col)


func _build_event_layer() -> void:
	_event_node = Node2D.new()
	_event_node.name = "PlanetEventLayer"
	_event_node.draw.connect(_on_draw_event)
	add_child(_event_node)


func _on_draw_event() -> void:
	if _current_event == "none":
		return

	var vp = get_viewport().get_visible_rect().size

	match _current_event:
		"dust_storm":
			var alpha = sin(_event_progress * PI) * 0.28
			var y_mid = _event_data.get("y_mid", vp.y * 0.6)
			var h = _event_data.get("height", 200.0)
			var rect = Rect2(0, y_mid - h * 0.5, vp.x, h)
			_event_node.draw_rect(rect, Color(0.45, 0.22, 0.12, alpha))

		"atmospheric_meteor":
			var start = _event_data.start
			var dir = _event_data.dir
			var length = _event_data.length
			var pos = start + dir * (length * _event_progress * 1.5)
			var tail = pos - dir * 65.0
			var alpha = sin(_event_progress * PI) * 0.75
			_event_node.draw_line(tail, pos, Color(1.0, 0.55, 0.25, alpha * 0.6), 2.5)
			_event_node.draw_circle(pos, 3.5, Color(1.0, 0.9, 0.7, alpha))

		"twin_star":
			var pos = _event_data.pos
			var alpha = sin(_event_progress * PI) * 0.6
			var rad = 3.0 + sin(_event_progress * PI * 3.0) * 1.5
			_event_node.draw_circle(pos - Vector2(5, 0), rad, Color(0.95, 0.85, 0.6, alpha))
			_event_node.draw_circle(pos + Vector2(5, 0), rad * 0.8, Color(0.85, 0.90, 1.0, alpha * 0.9))

		"horizon_lightning":
			var x = _event_data.x
			var y = _event_data.y
			var alpha = sin(_event_progress * PI) * 0.35
			_event_node.draw_circle(Vector2(x, y), 90.0, Color(0.85, 0.55, 0.45, alpha * 0.3))


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
