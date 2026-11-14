class_name OceanBackground
extends BackgroundBase
# Latar bawah air / lautan prosedural untuk Dodge 'em All.
# Menyediakan gradien laut bertingkat (turquoise ke midnight blue),
# sinar cahaya (god rays) miring bergoyang, caustics halus, partikel gelembung naik,
# plankton bercahaya, siluet karang/flora laut di dasar, dan event bayangan kedalaman.

# Sakelar performa untuk perangkat Android menengah / low-end
const ENABLE_GOD_RAYS = true
const ENABLE_CAUSTICS = true
const ENABLE_SEABED_FLORA = true
const ENABLE_OCEAN_EVENTS = true

const BUBBLE_COUNT = 30
const PLANKTON_COUNT = 25
const THEME_TRANSITION_TIME = 2.0

# Interval event lautan (detik)
const EVENT_INTERVAL_MIN = 12.0
const EVENT_INTERVAL_MAX = 25.0
const EVENT_INTERVAL_DANGER_MIN = 7.0
const EVENT_INTERVAL_DANGER_MAX = 14.0

# Palet warna per pita wave (Dangkal -> Menengah -> Laut Dalam)
const PALETTES = {
	"calm": {
		"top": Color(0.04, 0.16, 0.22, 1.0),
		"bottom": Color(0.02, 0.08, 0.14, 1.0),
		"god_rays": Color(0.20, 0.60, 0.65, 0.12),
		"caustics": Color(0.30, 0.75, 0.80, 0.08),
		"seabed": Color(0.02, 0.06, 0.10, 0.65)
	},
	"dramatic": {
		"top": Color(0.02, 0.08, 0.18, 1.0),
		"bottom": Color(0.01, 0.04, 0.12, 1.0),
		"god_rays": Color(0.12, 0.40, 0.60, 0.09),
		"caustics": Color(0.18, 0.50, 0.70, 0.06),
		"seabed": Color(0.01, 0.04, 0.08, 0.75)
	},
	"danger": {
		"top": Color(0.01, 0.03, 0.10, 1.0),
		"bottom": Color(0.005, 0.01, 0.05, 1.0),
		"god_rays": Color(0.08, 0.25, 0.45, 0.05),
		"caustics": Color(0.10, 0.35, 0.50, 0.04),
		"seabed": Color(0.005, 0.02, 0.05, 0.85)
	}
}

# Node referensi internal
var _gradient_rect: ColorRect
var _gradient_material: ShaderMaterial
var _caustics_rect: ColorRect
var _caustics_material: ShaderMaterial
var _god_rays_node: Node2D
var _seabed_node: Node2D
var _bubble_particles: CPUParticles2D
var _plankton_particles: CPUParticles2D
var _event_node: Node2D

# State warna & transisi
var _current_top: Color = PALETTES["calm"]["top"]
var _current_bottom: Color = PALETTES["calm"]["bottom"]
var _current_god_rays: Color = PALETTES["calm"]["god_rays"]
var _current_caustics: Color = PALETTES["calm"]["caustics"]
var _current_seabed: Color = PALETTES["calm"]["seabed"]
var _theme_tween: Tween

# State animasi flora & sinar
var _sway_time = 0.0

# State event visual lautan
var _event_timer = 15.0
var _current_event = "none" # "none", "bubble_burst", "deep_whale_shadow", "deep_school", "light_sweep"
var _event_progress = 0.0
var _event_duration = 1.0
var _event_data = {}


func _ready() -> void:
	super._ready()
	_build_gradient_layer()
	_build_caustics_layer()
	_build_god_rays_layer()
	_build_particles()
	_build_seabed_layer()
	_build_event_layer()

	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()
	_reset_event_timer()


func _process(delta: float) -> void:
	_sway_time += delta

	if _god_rays_node:
		_god_rays_node.queue_redraw()
	if _seabed_node:
		_seabed_node.queue_redraw()

	if is_round_active and ENABLE_OCEAN_EVENTS:
		_update_ocean_events(delta)


func _on_viewport_size_changed() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	if _gradient_rect:
		_gradient_rect.size = vp_size
	if _caustics_rect:
		_caustics_rect.size = vp_size
	if _bubble_particles:
		_bubble_particles.position = Vector2(vp_size.x * 0.5, vp_size.y + 20)
		_bubble_particles.emission_rect_extents = Vector2(vp_size.x * 0.5, 20)
	if _plankton_particles:
		_plankton_particles.position = vp_size * 0.5
		_plankton_particles.emission_rect_extents = vp_size * 0.5


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
	var s_rays = _current_god_rays
	var s_caustics = _current_caustics
	var s_seabed = _current_seabed

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

	if _caustics_material:
		_theme_tween.tween_method(func(val):
			_current_caustics = val
			_caustics_material.set_shader_parameter("caustic_color", val)
		, s_caustics, target["caustics"], duration)

	_theme_tween.tween_method(func(val):
		_current_god_rays = val
	, s_rays, target["god_rays"], duration)

	_theme_tween.tween_method(func(val):
		_current_seabed = val
	, s_seabed, target["seabed"], duration)


# ---------------- Event Lautan Prosedural ----------------

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
	if is_instance_valid(_bubble_particles):
		_bubble_particles.emitting = true
	if is_instance_valid(_plankton_particles):
		_plankton_particles.emitting = true


func deactivate() -> void:
	super.deactivate()
	if is_instance_valid(_bubble_particles):
		_bubble_particles.emitting = false
	if is_instance_valid(_plankton_particles):
		_plankton_particles.emitting = false
	if _theme_tween:
		_theme_tween.kill()


func _reset_event_timer() -> void:
	var min_i = EVENT_INTERVAL_DANGER_MIN if current_wave >= 8 else EVENT_INTERVAL_MIN
	var max_i = EVENT_INTERVAL_DANGER_MAX if current_wave >= 8 else EVENT_INTERVAL_MAX
	_event_timer = randf_range(min_i, max_i)


func _update_ocean_events(delta: float) -> void:
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
	var pool = ["bubble_burst", "deep_whale_shadow", "deep_school", "light_sweep"]

	_current_event = pool[randi() % pool.size()]
	_event_progress = 0.0

	match _current_event:
		"bubble_burst":
			_event_duration = 2.5
			_event_data = {
				"x": randf_range(vp.x * 0.2, vp.x * 0.8)
			}
		"deep_whale_shadow":
			_event_duration = 5.0
			_event_data = {
				"y": randf_range(vp.y * 0.45, vp.y * 0.75),
				"start_x": -150.0,
				"end_x": vp.x + 150.0
			}
		"deep_school":
			_event_duration = 3.5
			_event_data = {
				"y": randf_range(vp.y * 0.3, vp.y * 0.6),
				"start_x": vp.x + 80.0,
				"end_x": -80.0
			}
		"light_sweep":
			_event_duration = 2.8
			_event_data = {
				"start_x": randf_range(40, vp.x - 40)
			}


# ---------------- Konstruksi Layer Prosedural ----------------

func _build_gradient_layer() -> void:
	_gradient_rect = ColorRect.new()
	_gradient_rect.name = "WaterGradient"
	_gradient_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	render_mode unshaded;

	uniform vec4 top_color : source_color = vec4(0.04, 0.16, 0.22, 1.0);
	uniform vec4 bottom_color : source_color = vec4(0.02, 0.08, 0.14, 1.0);

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


func _build_caustics_layer() -> void:
	if not ENABLE_CAUSTICS:
		return

	_caustics_rect = ColorRect.new()
	_caustics_rect.name = "CausticsLayer"
	_caustics_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	render_mode unshaded;

	uniform vec4 caustic_color : source_color = vec4(0.30, 0.75, 0.80, 0.08);
	uniform float speed = 0.05;

	void fragment() {
		vec2 p = UV * 3.5;
		float t = TIME * speed;
		float c1 = sin(p.x * 3.0 + sin(p.y * 2.0 + t)) * cos(p.y * 3.0 + t * 0.7);
		float c2 = sin(p.x * 2.0 - t * 0.8) * cos(p.y * 2.5 + sin(p.x * 1.5 + t));
		float caustic = smoothstep(0.2, 0.8, (c1 + c2) * 0.5 + 0.5);
		float depth_fade = 1.0 - smoothstep(0.1, 0.9, UV.y);
		COLOR = vec4(caustic_color.rgb, caustic_color.a * caustic * depth_fade);
	}
	"""
	_caustics_material = ShaderMaterial.new()
	_caustics_material.shader = shader
	_caustics_material.set_shader_parameter("caustic_color", _current_caustics)
	_caustics_rect.material = _caustics_material
	add_child(_caustics_rect)


func _build_god_rays_layer() -> void:
	if not ENABLE_GOD_RAYS:
		return

	_god_rays_node = Node2D.new()
	_god_rays_node.name = "GodRays"
	_god_rays_node.draw.connect(_on_draw_god_rays)
	add_child(_god_rays_node)


func _on_draw_god_rays() -> void:
	var vp = get_viewport().get_visible_rect().size
	var ray_count = 4
	var t = _sway_time * 0.4

	for i in range(ray_count):
		var base_origin_x = vp.x * (0.2 + 0.2 * i) + sin(t + i * 1.2) * 25.0
		var width_top = 20.0 + sin(t * 0.7 + i) * 8.0
		var width_bottom = 90.0 + cos(t * 0.5 + i) * 20.0
		var target_x = base_origin_x + 120.0 + sin(t * 0.8 + i) * 40.0

		var poly = PackedVector2Array([
			Vector2(base_origin_x - width_top * 0.5, -10),
			Vector2(base_origin_x + width_top * 0.5, -10),
			Vector2(target_x + width_bottom * 0.5, vp.y * 0.85),
			Vector2(target_x - width_bottom * 0.5, vp.y * 0.85)
		])
		_god_rays_node.draw_colored_polygon(poly, _current_god_rays)


func _build_particles() -> void:
	# Partikel gelembung naik
	var bubble_tex = _generate_bubble_texture(5)
	_bubble_particles = CPUParticles2D.new()
	_bubble_particles.name = "BubbleParticles"
	_bubble_particles.texture = bubble_tex
	_bubble_particles.amount = BUBBLE_COUNT
	_bubble_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_bubble_particles.direction = Vector2(0, -1) # Naik ke atas
	_bubble_particles.spread = 15.0
	_bubble_particles.gravity = Vector2.ZERO
	_bubble_particles.initial_velocity_min = 28.0
	_bubble_particles.initial_velocity_max = 60.0
	_bubble_particles.scale_amount_min = 0.6
	_bubble_particles.scale_amount_max = 1.4
	_bubble_particles.color = Color(0.6, 0.85, 0.95, 0.4)
	_bubble_particles.lifetime = 14.0
	_bubble_particles.preprocess = 10.0
	add_child(_bubble_particles)

	# Partikel plankton melayang lembut
	var plankton_tex = _generate_bubble_texture(3)
	_plankton_particles = CPUParticles2D.new()
	_plankton_particles.name = "PlanktonParticles"
	_plankton_particles.texture = plankton_tex
	_plankton_particles.amount = PLANKTON_COUNT
	_plankton_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_plankton_particles.direction = Vector2(0.5, -0.2)
	_plankton_particles.spread = 80.0
	_plankton_particles.gravity = Vector2(0, -2.0)
	_plankton_particles.initial_velocity_min = 4.0
	_plankton_particles.initial_velocity_max = 12.0
	_plankton_particles.scale_amount_min = 0.5
	_plankton_particles.scale_amount_max = 1.2
	_plankton_particles.color = Color(0.3, 0.9, 0.8, 0.3)
	_plankton_particles.lifetime = 12.0
	_plankton_particles.preprocess = 8.0
	add_child(_plankton_particles)


func _build_seabed_layer() -> void:
	if not ENABLE_SEABED_FLORA:
		return

	_seabed_node = Node2D.new()
	_seabed_node.name = "SeabedFlora"
	_seabed_node.draw.connect(_on_draw_seabed)
	add_child(_seabed_node)


func _on_draw_seabed() -> void:
	var vp = get_viewport().get_visible_rect().size
	var base_y = vp.y

	# Siluet bukit karang dasar
	var pts = PackedVector2Array()
	pts.append(Vector2(0, base_y))
	var step = 25.0
	var x = 0.0
	while x <= vp.x + step:
		var y = base_y - 45.0 + sin(x / 80.0) * 18.0 + cos(x / 40.0) * 8.0
		pts.append(Vector2(x, y))
		x += step
	pts.append(Vector2(vp.x, base_y))
	_seabed_node.draw_colored_polygon(pts, _current_seabed)

	# Rumput laut bergoyang
	var t = _sway_time * 1.5
	var stalk_count = 6
	for s in range(stalk_count):
		var root_x = vp.x * (0.12 + 0.15 * s)
		var root_y = base_y - 20.0
		var h = 45.0 + (s % 3) * 12.0
		var sway = sin(t + s * 1.4) * 14.0

		_seabed_node.draw_line(Vector2(root_x, root_y), Vector2(root_x + sway * 0.4, root_y - h * 0.5), _current_seabed, 4.0)
		_seabed_node.draw_line(Vector2(root_x + sway * 0.4, root_y - h * 0.5), Vector2(root_x + sway, root_y - h), _current_seabed, 2.5)


func _build_event_layer() -> void:
	_event_node = Node2D.new()
	_event_node.name = "OceanEventLayer"
	_event_node.draw.connect(_on_draw_event)
	add_child(_event_node)


func _on_draw_event() -> void:
	if _current_event == "none":
		return

	var vp = get_viewport().get_visible_rect().size

	match _current_event:
		"bubble_burst":
			var x = _event_data.get("x", vp.x * 0.5)
			var y = vp.y - _event_progress * vp.y * 0.9
			var alpha = sin(_event_progress * PI) * 0.6
			for b in range(5):
				var offset = Vector2(sin(b * 1.5) * 18.0, b * 14.0)
				_event_node.draw_circle(Vector2(x, y) + offset, 4.0 + b, Color(0.7, 0.9, 1.0, alpha * 0.5))

		"deep_whale_shadow":
			var sx = _event_data.start_x
			var ex = _event_data.end_x
			var cur_x = lerp(sx, ex, _event_progress)
			var cur_y = _event_data.y
			var alpha = sin(_event_progress * PI) * 0.18

			# Siluet lonjong raksasa buram (paus raksasa jauh di kedalaman)
			var poly = PackedVector2Array([
				Vector2(cur_x + 90, cur_y),
				Vector2(cur_x + 40, cur_y - 24),
				Vector2(cur_x - 50, cur_y - 18),
				Vector2(cur_x - 95, cur_y - 4),
				Vector2(cur_x - 120, cur_y - 16),
				Vector2(cur_x - 110, cur_y),
				Vector2(cur_x - 120, cur_y + 16),
				Vector2(cur_x - 95, cur_y + 4),
				Vector2(cur_x - 50, cur_y + 18),
				Vector2(cur_x + 40, cur_y + 24)
			])
			_event_node.draw_colored_polygon(poly, Color(0.01, 0.05, 0.12, alpha))

		"deep_school":
			var sx = _event_data.start_x
			var ex = _event_data.end_x
			var cur_x = lerp(sx, ex, _event_progress)
			var cur_y = _event_data.y
			var alpha = sin(_event_progress * PI) * 0.25
			for f in range(8):
				var f_pos = Vector2(cur_x + sin(f) * 25.0, cur_y + cos(f * 2.0) * 15.0)
				_event_node.draw_circle(f_pos, 2.0, Color(0.2, 0.5, 0.7, alpha))

		"light_sweep":
			var start_x = _event_data.start_x
			var alpha = sin(_event_progress * PI) * 0.15
			var sweep_offset = sin(_event_progress * PI) * 60.0
			var poly = PackedVector2Array([
				Vector2(start_x - 15, -10),
				Vector2(start_x + 15, -10),
				Vector2(start_x + sweep_offset + 100, vp.y),
				Vector2(start_x + sweep_offset - 100, vp.y)
			])
			_event_node.draw_colored_polygon(poly, Color(0.4, 0.8, 0.9, alpha))


func _generate_bubble_texture(radius: int) -> ImageTexture:
	var diameter = radius * 2
	var img = Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var center = Vector2(radius, radius)
	for y in range(diameter):
		for x in range(diameter):
			var dist = center.distance_to(Vector2(x + 0.5, y + 0.5))
			var ring = 1.0 - abs(dist - (radius * 0.75)) / (radius * 0.25)
			var a = clamp(ring, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * 0.9))
	return ImageTexture.create_from_image(img)
