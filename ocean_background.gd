extends CanvasLayer
# Latar bawah air prosedural: hanya visual, tanpa collision dan tanpa group gameplay.

const DEPTH_SHALLOW = 0
const DEPTH_MID = 1
const DEPTH_DEEP = 2

@export var event_interval_min = 12.0 # Jeda minimum antar event visual.
@export var event_interval_max = 25.0 # Jeda maksimum antar event visual.
@export var theme_transition_time = 2.0 # Durasi transisi suasana antar wave.
@export var bubble_rise_speed_min = 22.0 # Kecepatan gelembung terkecil.
@export var bubble_rise_speed_max = 48.0 # Kecepatan gelembung terbesar.
@export var plankton_drift_speed = 7.0 # Kecepatan gerak plankton.
@export var event_bubble_amount = 16 # Jumlah gelembung pada event semburan.
@export var distant_fish_speed = 10.0 # Kecepatan sangat lambat ikan siluet jauh.

const SHALLOW_TOP = Color("#4daeb0")
const SHALLOW_BOTTOM = Color("#0c536b")
const MID_TOP = Color("#247d91")
const MID_BOTTOM = Color("#092d4e")
const DEEP_TOP = Color("#123b65")
const DEEP_BOTTOM = Color("#04152e")

var _rng = RandomNumberGenerator.new()
var _event_timer: Timer
var _event_active = false
var _event_node: Node2D
var _event_tween: Tween
var _round_active = false
var _theme_depth = DEPTH_SHALLOW
var _theme_top = SHALLOW_TOP
var _theme_bottom = SHALLOW_BOTTOM
var _ray_alpha = 0.18
var _plankton_alpha = 0.18
var _bubble_alpha = 0.8

@onready var _water = $WaterGradient
@onready var _rays = $Rays
@onready var _bubbles = $Bubbles
@onready var _plankton = $Plankton
@onready var _depth_silhouettes = $DepthSilhouettes

func _ready():
	_rng.randomize()
	_event_timer = Timer.new()
	_event_timer.one_shot = true
	add_child(_event_timer)
	_event_timer.timeout.connect(_on_event_timer_timeout)
	_event_node = Node2D.new()
	_event_node.name = "VisualEvent"
	add_child(_event_node)
	_bubbles.texture = _make_particle_texture(Color(0.75, 0.95, 1.0, 0.7), 10)
	_plankton.texture = _make_particle_texture(Color(0.62, 0.96, 0.85, 0.7), 5)
	_bubbles.initial_velocity_min = bubble_rise_speed_min
	_bubbles.initial_velocity_max = bubble_rise_speed_max
	_plankton.initial_velocity_min = plankton_drift_speed * 0.3
	_plankton.initial_velocity_max = plankton_drift_speed
	get_viewport().size_changed.connect(_update_play_area)
	_update_play_area()
	_apply_theme()

func _update_play_area():
	var area = get_viewport().get_visible_rect()
	var size = area.size
	$WaterGradient.position = area.position
	$WaterGradient.size = size
	_rays.position = area.position
	_rays.size = size
	_bubbles.position = area.position + Vector2(size.x * 0.5, size.y + 12)
	_bubbles.emission_rect_extents = Vector2(size.x * 0.5, 4.0)
	_plankton.position = area.position + size * 0.5
	_plankton.emission_rect_extents = size * 0.5
	_rebuild_rays(size)
	_rebuild_depth_silhouettes(size)

func _rebuild_depth_silhouettes(size):
	for child in _depth_silhouettes.get_children():
		child.queue_free()
	_depth_silhouettes.position = get_viewport().get_visible_rect().position
	for i in 7:
		var grass = Polygon2D.new()
		grass.color = Color(0.015, 0.09, 0.12, 0.34)
		var x = size.x * (0.04 + i * 0.15)
		var height = 35.0 + (i % 3) * 18.0
		grass.polygon = PackedVector2Array([Vector2(x, size.y), Vector2(x + 8, size.y), Vector2(x + 5, size.y - height * 0.45), Vector2(x + 18, size.y - height), Vector2(x + 14, size.y - height * 0.25), Vector2(x + 25, size.y - height * 0.7), Vector2(x + 20, size.y), Vector2(x + 28, size.y)])
		_depth_silhouettes.add_child(grass)
	var rock = Polygon2D.new()
	rock.color = Color(0.01, 0.07, 0.10, 0.38)
	rock.polygon = PackedVector2Array([Vector2(0, size.y), Vector2(size.x, size.y), Vector2(size.x * 0.88, size.y - 24), Vector2(size.x * 0.74, size.y - 12), Vector2(size.x * 0.6, size.y - 32), Vector2(size.x * 0.42, size.y - 10), Vector2(size.x * 0.2, size.y - 26), Vector2(size.x * 0.08, size.y - 8)])
	_depth_silhouettes.add_child(rock)
	for i in 3:
		var fish = Polygon2D.new()
		fish.color = Color(0.01, 0.08, 0.14, 0.16)
		fish.polygon = PackedVector2Array([Vector2(-20, 0), Vector2(8, -7), Vector2(22, 0), Vector2(8, 7), Vector2(-8, 3), Vector2(-15, 10), Vector2(-13, 1), Vector2(-15, -10), Vector2(-8, -3)])
		fish.position = Vector2(-50.0 - i * size.x * 0.32, size.y * (0.28 + i * 0.1))
		_depth_silhouettes.add_child(fish)
		var tween = create_tween().set_loops()
		var duration = maxf(8.0, size.x / distant_fish_speed) + i * 8.0
		tween.tween_property(fish, "position:x", size.x + 60.0, duration)
		tween.tween_property(fish, "position:x", -60.0, duration)
		fish.tree_exiting.connect(tween.kill)

func _rebuild_rays(size):
	for child in _rays.get_children():
		child.queue_free()
	for i in 4:
		var ray = Polygon2D.new()
		ray.color = Color(0.7, 0.95, 0.94, _ray_alpha)
		var x = size.x * (0.12 + i * 0.25)
		var width = size.x * (0.10 + (i % 2) * 0.04)
		ray.polygon = PackedVector2Array([Vector2(x, 0), Vector2(x + width, 0), Vector2(x + width * 0.15 + size.x * 0.18, size.y), Vector2(x - width * 0.45 + size.x * 0.06, size.y)])
		_rays.add_child(ray)
		var tween = create_tween().set_loops()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(ray, "position:x", _rng.randf_range(-12.0, 12.0), _rng.randf_range(4.0, 7.0))
		tween.tween_property(ray, "position:x", 0.0, _rng.randf_range(4.0, 7.0))
		ray.tree_exiting.connect(tween.kill)

func _process(_delta):
	# Hanya menjaga event timer; animasi utama berjalan lewat shader, partikel, dan Tween.
	_apply_theme()
	if _round_active and _event_timer.is_stopped() and not _event_active:
		_schedule_event()

func start_round():
	_round_active = true
	_schedule_event()

func stop_round():
	_round_active = false
	_event_timer.stop()
	_clear_event()

func set_depth_theme(wave):
	_theme_depth = DEPTH_SHALLOW if wave <= 3 else DEPTH_MID if wave <= 7 else DEPTH_DEEP
	var top = SHALLOW_TOP
	var bottom = SHALLOW_BOTTOM
	var rays = 0.18
	var plankton = 0.18
	var bubbles = 0.8
	if _theme_depth == DEPTH_MID:
		top = MID_TOP
		bottom = MID_BOTTOM
		rays = 0.10
		plankton = 0.25
	if _theme_depth == DEPTH_DEEP:
		top = DEEP_TOP
		bottom = DEEP_BOTTOM
		rays = 0.04
		plankton = 0.55
		bubbles = 0.35
	if _event_tween:
		_event_tween.kill()
	_event_tween = create_tween()
	_event_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_event_tween.set_parallel(true)
	_event_tween.tween_property(self, "_theme_top", top, theme_transition_time)
	_event_tween.tween_property(self, "_theme_bottom", bottom, theme_transition_time)
	_event_tween.tween_property(self, "_ray_alpha", rays, theme_transition_time)
	_event_tween.tween_property(self, "_plankton_alpha", plankton, theme_transition_time)
	_event_tween.tween_property(self, "_bubble_alpha", bubbles, theme_transition_time)
	_event_tween.finished.connect(_apply_theme)
	_apply_theme()

func reset_to_shallow():
	stop_round()
	_theme_top = SHALLOW_TOP
	_theme_bottom = SHALLOW_BOTTOM
	_ray_alpha = 0.18
	_plankton_alpha = 0.18
	_bubble_alpha = 0.8
	_apply_theme()

func _apply_theme():
	_water.material.set_shader_parameter("top_color", _theme_top)
	_water.material.set_shader_parameter("bottom_color", _theme_bottom)
	for ray in _rays.get_children():
		ray.color.a = _ray_alpha
	_bubbles.modulate.a = _bubble_alpha
	_plankton.modulate.a = _plankton_alpha

func _schedule_event():
	_event_timer.start(_rng.randf_range(event_interval_min, event_interval_max))

func _on_event_timer_timeout():
	if not _round_active or _event_active:
		return
	_event_active = true
	match _rng.randi_range(0, 3):
		0: _show_fish_school()
		1: _show_bubble_burst()
		2: _show_distant_shape()
		3: _show_light_sweep()

func _show_fish_school():
	var fish = Node2D.new()
	_event_node.add_child(fish)
	for i in 5:
		var shape = Polygon2D.new()
		shape.color = Color(0.02, 0.12, 0.18, 0.22)
		shape.polygon = PackedVector2Array([Vector2(-18, 0), Vector2(8, -6), Vector2(18, 0), Vector2(8, 6), Vector2(-4, 2), Vector2(-12, 9), Vector2(-9, 1), Vector2(-12, -9), Vector2(-4, -2)])
		shape.position = Vector2(-80.0 - i * 35.0, 140.0 + i * 22.0)
		fish.add_child(shape)
	var area = get_viewport().get_visible_rect()
	fish.position = Vector2(area.position.x, area.position.y)
	var tween = create_tween()
	tween.tween_property(fish, "position:x", area.size.x + 180.0, 8.0)
	tween.finished.connect(func(): _finish_event(fish))

func _show_bubble_burst():
	var burst = CPUParticles2D.new()
	burst.amount = event_bubble_amount
	burst.one_shot = true
	burst.explosiveness = 0.85
	burst.lifetime = 2.8
	burst.texture = _make_particle_texture(Color(0.65, 0.93, 1.0, 0.7), 14)
	burst.direction = Vector2(0, -1)
	burst.spread = 28.0
	burst.initial_velocity_min = 65.0
	burst.initial_velocity_max = 120.0
	burst.scale_amount_min = 0.5
	burst.scale_amount_max = 1.2
	burst.position = Vector2(get_viewport().get_visible_rect().get_center().x, get_viewport().get_visible_rect().end.y - 18.0)
	_event_node.add_child(burst)
	burst.finished.connect(func(): _finish_event(burst))
	burst.restart()

func _show_distant_shape():
	var shape = Polygon2D.new()
	shape.color = Color(0.02, 0.10, 0.16, 0.28)
	shape.polygon = PackedVector2Array([Vector2(-80, 0), Vector2(-28, -18), Vector2(52, -14), Vector2(82, 0), Vector2(52, 14), Vector2(-28, 18)])
	shape.position = Vector2(-100, get_viewport().get_visible_rect().size.y * 0.35)
	_event_node.add_child(shape)
	var area = get_viewport().get_visible_rect()
	var tween = create_tween()
	tween.tween_property(shape, "position:x", area.size.x + 120.0, 11.0)
	tween.finished.connect(func(): _finish_event(shape))

func _show_light_sweep():
	var sweep = Polygon2D.new()
	sweep.color = Color(0.75, 1.0, 0.96, 0.0)
	var area = get_viewport().get_visible_rect()
	sweep.polygon = PackedVector2Array([Vector2(-80, 0), Vector2(30, 0), Vector2(area.size.x * 0.55, area.size.y), Vector2(area.size.x * 0.25, area.size.y)])
	_event_node.add_child(sweep)
	var tween = create_tween()
	tween.tween_property(sweep, "color:a", 0.16, 0.35)
	tween.tween_property(sweep, "position:x", area.size.x * 0.75, 1.4)
	tween.tween_property(sweep, "color:a", 0.0, 0.5)
	tween.finished.connect(func(): _finish_event(sweep))

func _finish_event(node):
	if is_instance_valid(node):
		node.queue_free()
	_event_active = false
	if _round_active:
		_schedule_event()

func _clear_event():
	for child in _event_node.get_children():
		child.queue_free()
	_event_active = false

func _make_particle_texture(color, size):
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size - 1, size - 1) * 0.5
	for y in size:
		for x in size:
			var distance = Vector2(x, y).distance_to(center) / (size * 0.5)
			var alpha = clampf(1.0 - distance, 0.0, 1.0) * color.a
			image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(image)
