class_name SpaceBackground
extends BackgroundBase
# Latar luar angkasa prosedural untuk Dodge 'em All.
# Menyediakan gradien langit dinamis, nebula shader, 3 layer bintang parallax,
# planet/bulan jauh, asteroid siluet, event visual acak, dan transisi tema per wave.

# Sakelar performa untuk perangkat Android menengah / low-end
const ENABLE_NEBULA_SHADER = true
const ENABLE_CELESTIAL_BODIES = true
const ENABLE_SPACE_EVENTS = true

# Konfigurasi partikel bintang parallax (jauh, tengah, dekat)
# Total bintang = 40 + 30 + 20 = 90 partikel (di bawah batas 100)
const STAR_COUNTS = [40, 30, 20]
const PARALLAX_SPEEDS = [15.0, 35.0, 70.0]  # kecepatan scroll turun (px/detik)

# Interval event luar angkasa (detik)
const EVENT_INTERVAL_MIN = 12.0
const EVENT_INTERVAL_MAX = 25.0
const EVENT_INTERVAL_DANGER_MIN = 7.0
const EVENT_INTERVAL_DANGER_MAX = 14.0
const THEME_TRANSITION_TIME = 2.0

# Palet tema per wave (Wave 1–3: Tenang, Wave 4–7: Dramatis Teal/Magenta, Wave 8–10: Bahaya Merah/Oranye)
const THEMES = {
	"calm": {
		"top": Color(0.02, 0.02, 0.08, 1.0),
		"bottom": Color(0.06, 0.05, 0.16, 1.0),
		"nebula1": Color(0.18, 0.06, 0.28, 0.16),
		"nebula2": Color(0.04, 0.20, 0.26, 0.14)
	},
	"dramatic": {
		"top": Color(0.03, 0.02, 0.09, 1.0),
		"bottom": Color(0.08, 0.03, 0.14, 1.0),
		"nebula1": Color(0.30, 0.04, 0.22, 0.22),
		"nebula2": Color(0.03, 0.26, 0.24, 0.20)
	},
	"danger": {
		"top": Color(0.06, 0.02, 0.03, 1.0),
		"bottom": Color(0.14, 0.04, 0.04, 1.0),
		"nebula1": Color(0.36, 0.07, 0.04, 0.22),
		"nebula2": Color(0.32, 0.16, 0.03, 0.18)
	}
}

# Node referensi internal
var _gradient_rect: ColorRect
var _gradient_material: ShaderMaterial
var _nebula_rect: ColorRect
var _nebula_material: ShaderMaterial
var _star_layers: Array[CPUParticles2D] = []
var _celestial_node: Node2D
var _asteroid_node: Node2D
var _event_node: Node2D

# State transisi tema warna
var _current_top: Color = THEMES["calm"]["top"]
var _current_bottom: Color = THEMES["calm"]["bottom"]
var _current_neb1: Color = THEMES["calm"]["nebula1"]
var _current_neb2: Color = THEMES["calm"]["nebula2"]
var _theme_tween: Tween
var _current_wave: int = 1

# State posisi benda langit & asteroid
var _planet_pos = Vector2(370, 160)
var _moon_pos = Vector2(85, 430)
var _asteroid_pos = Vector2(100, -50)
var _asteroid_rot = 0.0
var _asteroid_vel = Vector2(12.0, 24.0)

# State event visual luar angkasa
var _event_timer = 15.0
var _current_event = "none" # "none", "shooting_stars", "comet", "satellite", "supernova", "mothership"
var _event_progress = 0.0
var _event_duration = 1.0
var _event_data = {}


func _ready():
	layer = -1
	_build_gradient_layer()
	_build_nebula_layer()
	_build_star_layers()
	_build_celestial_layer()
	_build_asteroid_layer()
	_build_event_layer()

	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()
	_reset_event_timer()


func _process(delta):
	# Pergerakan benda langit jauh
	_planet_pos += Vector2(-1.0, 2.0) * delta
	_moon_pos += Vector2(0.8, 1.5) * delta

	var vp_size = get_viewport().get_visible_rect().size
	if _planet_pos.y > vp_size.y + 100:
		_planet_pos.y = -100
		_planet_pos.x = randf_range(100, vp_size.x - 50)
	if _moon_pos.y > vp_size.y + 60:
		_moon_pos.y = -60
		_moon_pos.x = randf_range(40, vp_size.x - 40)

	# Pergerakan asteroid melintas lambat
	_asteroid_pos += _asteroid_vel * delta
	_asteroid_rot += 0.4 * delta
	if _asteroid_pos.y > vp_size.y + 60 or _asteroid_pos.x > vp_size.x + 60:
		_asteroid_pos = Vector2(randf_range(20, vp_size.x * 0.7), -40)
		_asteroid_vel = Vector2(randf_range(8.0, 18.0), randf_range(20.0, 35.0))

	if _celestial_node:
		_celestial_node.queue_redraw()
	if _asteroid_node:
		_asteroid_node.queue_redraw()

	# Update event visual acak saat ronde berjalan
	if ENABLE_SPACE_EVENTS and is_round_active:
		_update_space_events(delta)


func _on_viewport_size_changed():
	var vp_size = get_viewport().get_visible_rect().size
	if _gradient_rect:
		_gradient_rect.size = vp_size
	if _nebula_rect:
		_nebula_rect.size = vp_size

	for i in range(_star_layers.size()):
		var layer_node = _star_layers[i]
		if is_instance_valid(layer_node):
			layer_node.position = vp_size * 0.5
			layer_node.emission_rect_extents = vp_size * 0.5
			var speed = PARALLAX_SPEEDS[i]
			layer_node.lifetime = max(4.0, vp_size.y / speed)


# --- TRANSISI TEMA PER WAVE ---

func set_wave_theme(wave_num: int):
	_current_wave = wave_num
	var theme_key = "calm"
	if wave_num >= 8:
		theme_key = "danger"
	elif wave_num >= 4:
		theme_key = "dramatic"

	_apply_theme(THEMES[theme_key], THEME_TRANSITION_TIME)


func reset_to_title_theme():
	_current_wave = 1
	_apply_theme(THEMES["calm"], THEME_TRANSITION_TIME)


func _apply_theme(target: Dictionary, duration: float):
	if _theme_tween:
		_theme_tween.kill()

	_theme_tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	var start_top = _current_top
	var start_bottom = _current_bottom
	var start_neb1 = _current_neb1
	var start_neb2 = _current_neb2

	_theme_tween.tween_method(func(val):
		_current_top = val
		if _gradient_material:
			_gradient_material.set_shader_parameter("top_color", val)
	, start_top, target["top"], duration)

	_theme_tween.tween_method(func(val):
		_current_bottom = val
		if _gradient_material:
			_gradient_material.set_shader_parameter("bottom_color", val)
	, start_bottom, target["bottom"], duration)

	if _nebula_material:
		_theme_tween.tween_method(func(val):
			_current_neb1 = val
			_nebula_material.set_shader_parameter("nebula_color1", val)
		, start_neb1, target["nebula1"], duration)

		_theme_tween.tween_method(func(val):
			_current_neb2 = val
			_nebula_material.set_shader_parameter("nebula_color2", val)
		, start_neb2, target["nebula2"], duration)


# --- EVENT LUAR ANGKASA (VISUAL ONLY) ---

func start_events():
	is_round_active = true
	_reset_event_timer()


func stop_events():
	is_round_active = false
	_current_event = "none"
	if _event_node:
		_event_node.queue_redraw()


func activate():
	super.activate()
	for p in _star_layers:
		if is_instance_valid(p):
			p.emitting = true


func deactivate():
	super.deactivate()
	for p in _star_layers:
		if is_instance_valid(p):
			p.emitting = false
	if _theme_tween:
		_theme_tween.kill()


func _reset_event_timer():
	var min_i = EVENT_INTERVAL_DANGER_MIN if _current_wave >= 8 else EVENT_INTERVAL_MIN
	var max_i = EVENT_INTERVAL_DANGER_MAX if _current_wave >= 8 else EVENT_INTERVAL_MAX
	_event_timer = randf_range(min_i, max_i)


func _update_space_events(delta):
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


func _spawn_random_event():
	var vp = get_viewport().get_visible_rect().size
	var pool = ["shooting_stars", "comet", "satellite", "supernova", "mothership"]
	# Pada wave bahaya (8–10), meteor dan komet lebih sering muncul
	if _current_wave >= 8:
		pool = ["shooting_stars", "shooting_stars", "comet", "comet", "supernova"]

	_current_event = pool[randi() % pool.size()]
	_event_progress = 0.0

	match _current_event:
		"shooting_stars":
			_event_duration = 0.9
			_event_data = {
				"start": Vector2(randf_range(50, vp.x - 50), randf_range(20, vp.y * 0.35)),
				"dir": Vector2(randf_range(0.6, 0.9), randf_range(0.8, 1.2)).normalized(),
				"length": randf_range(160, 260)
			}
		"comet":
			_event_duration = 3.2
			_event_data = {
				"start": Vector2(randf_range(vp.x * 0.6, vp.x + 40), -40),
				"end": Vector2(-60, randf_range(vp.y * 0.5, vp.y * 0.9)),
				"size": randf_range(5.0, 7.0)
			}
		"satellite":
			_event_duration = 6.0
			var y_pos = randf_range(80, vp.y * 0.45)
			_event_data = {
				"start": Vector2(-40, y_pos),
				"end": Vector2(vp.x + 40, y_pos + randf_range(-30, 30))
			}
		"supernova":
			_event_duration = 2.0
			_event_data = {
				"pos": Vector2(randf_range(80, vp.x - 80), randf_range(100, vp.y * 0.4)),
				"max_radius": randf_range(40, 60)
			}
		"mothership":
			_event_duration = 6.5
			var y_line = randf_range(60, vp.y * 0.25)
			_event_data = {
				"start": Vector2(-120, y_line),
				"end": Vector2(vp.x + 120, y_line + 20)
			}


func _build_event_layer():
	_event_node = Node2D.new()
	_event_node.name = "SpaceEvents"
	_event_node.draw.connect(_on_draw_events)
	add_child(_event_node)


func _on_draw_events():
	if _current_event == "none":
		return

	match _current_event:
		"shooting_stars":
			var start = _event_data.start
			var dir = _event_data.dir
			var length = _event_data.length
			var cur_head = start + dir * (length * _event_progress)
			var tail_len = min(60.0, length * _event_progress)
			var cur_tail = cur_head - dir * tail_len
			var alpha = sin(_event_progress * PI) * 0.85
			_event_node.draw_line(cur_tail, cur_head, Color(0.85, 0.95, 1.0, alpha), 2.2)

		"comet":
			var pos = _event_data.start.lerp(_event_data.end, _event_progress)
			var dir = (_event_data.end - _event_data.start).normalized()
			var tail = pos - dir * 75.0
			var alpha = sin(_event_progress * PI) * 0.75
			# Ekor komet segitiga pudar
			var side1 = pos - dir * 10.0 + dir.orthogonal() * 6.0
			var side2 = pos - dir * 10.0 - dir.orthogonal() * 6.0
			var tail_poly = PackedVector2Array([pos, side1, tail, side2])
			_event_node.draw_colored_polygon(tail_poly, Color(0.3, 0.6, 0.9, alpha * 0.25))
			# Inti komet
			_event_node.draw_circle(pos, _event_data.size, Color(0.9, 0.95, 1.0, alpha))

		"satellite":
			var pos = _event_data.start.lerp(_event_data.end, _event_progress)
			var alpha = 0.45
			# Badan satelit
			_event_node.draw_rect(Rect2(pos - Vector2(5, 3), Vector2(10, 6)), Color(0.5, 0.55, 0.65, alpha))
			# Panel surya kiri & kanan
			_event_node.draw_rect(Rect2(pos - Vector2(15, 2), Vector2(7, 4)), Color(0.2, 0.45, 0.75, alpha))
			_event_node.draw_rect(Rect2(pos + Vector2(8, -2), Vector2(7, 4)), Color(0.2, 0.45, 0.75, alpha))
			# Lampu kecil berkedip
			if fmod(_event_progress * 10.0, 1.0) < 0.4:
				_event_node.draw_circle(pos, 1.5, Color(1.0, 0.3, 0.3, 0.8))

		"supernova":
			var pos = _event_data.pos
			var radius = _event_data.max_radius * sin(_event_progress * PI)
			var alpha = sin(_event_progress * PI) * 0.35
			# Cahaya bulat mekar halus
			_event_node.draw_circle(pos, radius, Color(0.85, 0.8, 1.0, alpha))
			# Garis suar silang halus
			var flare_len = radius * 1.8
			_event_node.draw_line(pos - Vector2(flare_len, 0), pos + Vector2(flare_len, 0), Color(1.0, 0.9, 1.0, alpha * 0.6), 1.5)
			_event_node.draw_line(pos - Vector2(0, flare_len), pos + Vector2(0, flare_len), Color(1.0, 0.9, 1.0, alpha * 0.6), 1.5)

		"mothership":
			var pos = _event_data.start.lerp(_event_data.end, _event_progress)
			var alpha = 0.25
			# Siluet pesawat raksasa melintas jauh (poligon baji segitiga tumpul)
			var poly = PackedVector2Array([
				pos + Vector2(55, 0), pos + Vector2(-35, -16),
				pos + Vector2(-55, -8), pos + Vector2(-45, 0),
				pos + Vector2(-55, 8), pos + Vector2(-35, 16)
			])
			_event_node.draw_colored_polygon(poly, Color(0.12, 0.14, 0.22, alpha))
			# Dua titik pendorong mesin redup di belakang
			_event_node.draw_circle(pos + Vector2(-52, -4), 1.8, Color(0.2, 0.6, 0.9, alpha * 0.8))
			_event_node.draw_circle(pos + Vector2(-52, 4), 1.8, Color(0.2, 0.6, 0.9, alpha * 0.8))


# --- BANGUN ELEMEN PROSEDURAL ---

func _build_gradient_layer():
	_gradient_rect = ColorRect.new()
	_gradient_rect.name = "SkyGradient"
	_gradient_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	render_mode unshaded;

	uniform vec4 top_color : source_color = vec4(0.02, 0.02, 0.08, 1.0);
	uniform vec4 bottom_color : source_color = vec4(0.06, 0.05, 0.16, 1.0);

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


func _build_nebula_layer():
	if not ENABLE_NEBULA_SHADER:
		return

	_nebula_rect = ColorRect.new()
	_nebula_rect.name = "NebulaLayer"
	_nebula_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	render_mode unshaded;

	uniform vec4 nebula_color1 : source_color = vec4(0.18, 0.06, 0.28, 0.16);
	uniform vec4 nebula_color2 : source_color = vec4(0.04, 0.20, 0.26, 0.14);
	uniform float time_speed = 0.035;

	void fragment() {
		vec2 uv = UV * 2.5;
		float t = TIME * time_speed;
		float n1 = sin(uv.x * 2.8 + t * 0.7) * cos(uv.y * 2.2 - t * 0.5);
		float n2 = sin(uv.x * 1.5 - t * 0.4) * cos(uv.y * 3.4 + t * 0.8);
		float shape = smoothstep(-0.35, 0.65, n1 + n2 * 0.5);
		vec4 col = mix(nebula_color1, nebula_color2, sin(uv.y * 1.8 + t) * 0.5 + 0.5);
		COLOR = vec4(col.rgb, col.a * shape);
	}
	"""
	_nebula_material = ShaderMaterial.new()
	_nebula_material.shader = shader
	_nebula_material.set_shader_parameter("nebula_color1", _current_neb1)
	_nebula_material.set_shader_parameter("nebula_color2", _current_neb2)
	_nebula_rect.material = _nebula_material
	add_child(_nebula_rect)


func _build_star_layers():
	var star_tex = _generate_star_texture(6)
	var sizes = [1.2, 1.8, 2.6]
	var alphas = [0.45, 0.70, 0.95]

	for i in range(3):
		var p = CPUParticles2D.new()
		p.name = "StarField_%d" % i
		p.texture = star_tex
		p.amount = STAR_COUNTS[i]
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.direction = Vector2(0, 1) # Turun ke bawah
		p.spread = 0.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = PARALLAX_SPEEDS[i] * 0.9
		p.initial_velocity_max = PARALLAX_SPEEDS[i] * 1.1
		p.scale_amount_min = sizes[i] * 0.7
		p.scale_amount_max = sizes[i] * 1.3
		p.color = Color(1.0, 1.0, 1.0, alphas[i])

		var gradient = Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, alphas[i] * 0.3))
		gradient.add_point(0.25, Color(1, 1, 1, alphas[i] * 1.0))
		gradient.add_point(0.50, Color(1, 1, 1, alphas[i] * 0.4))
		gradient.add_point(0.75, Color(1, 1, 1, alphas[i] * 0.9))
		gradient.set_color(1, Color(1, 1, 1, alphas[i] * 0.3))
		p.color_ramp = gradient

		p.lifetime = 12.0
		p.preprocess = 12.0
		add_child(p)
		_star_layers.append(p)


func _build_celestial_layer():
	if not ENABLE_CELESTIAL_BODIES:
		return

	_celestial_node = Node2D.new()
	_celestial_node.name = "CelestialBodies"
	_celestial_node.draw.connect(_on_draw_celestial)
	add_child(_celestial_node)


func _on_draw_celestial():
	var p_rad = 54.0
	_celestial_node.draw_circle(_planet_pos, p_rad, Color(0.10, 0.12, 0.22, 0.55))
	_celestial_node.draw_circle(_planet_pos + Vector2(-8, -8), p_rad * 0.85, Color(0.16, 0.22, 0.38, 0.35))
	var ring_color = Color(0.25, 0.35, 0.50, 0.22)
	for r in range(2):
		_celestial_node.draw_arc(_planet_pos, p_rad + 18.0 + r * 6.0, -0.6, 2.5, 32, ring_color, 2.0)

	var m_rad = 18.0
	_celestial_node.draw_circle(_moon_pos, m_rad, Color(0.18, 0.14, 0.25, 0.45))
	_celestial_node.draw_circle(_moon_pos + Vector2(-3, -3), m_rad * 0.75, Color(0.28, 0.22, 0.38, 0.25))


func _build_asteroid_layer():
	_asteroid_node = Node2D.new()
	_asteroid_node.name = "DistantAsteroids"
	_asteroid_node.draw.connect(_on_draw_asteroids)
	add_child(_asteroid_node)


func _on_draw_asteroids():
	var poly = PackedVector2Array([
		Vector2(-10, -5), Vector2(-4, -12), Vector2(6, -9),
		Vector2(12, -2), Vector2(9, 8), Vector2(-2, 11), Vector2(-11, 4)
	])
	var transformed_poly = PackedVector2Array()
	var cos_a = cos(_asteroid_rot)
	var sin_a = sin(_asteroid_rot)
	for pt in poly:
		var rotated = Vector2(pt.x * cos_a - pt.y * sin_a, pt.x * sin_a + pt.y * cos_a)
		transformed_poly.append(_asteroid_pos + rotated)

	_asteroid_node.draw_colored_polygon(transformed_poly, Color(0.16, 0.15, 0.24, 0.35))


func _generate_star_texture(radius: int) -> ImageTexture:
	var diameter = radius * 2
	var img = Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var center = Vector2(radius, radius)
	for y in range(diameter):
		for x in range(diameter):
			var dist = center.distance_to(Vector2(x + 0.5, y + 0.5))
			var a = clamp(1.0 - (dist / float(radius)), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
