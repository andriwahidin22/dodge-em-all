extends Mob
# Dasher (lebah): masuk sedikit ke layar, diam sambil berkedip merah (peringatan),
# lalu melesat jauh lebih cepat ke posisi pemain saat itu.

enum State { ENTER, WARN, DASH }

@export var enter_depth = 60.0      # seberapa jauh masuk ke layar sebelum berhenti (piksel)
@export var warn_time = 1.0         # lama peringatan (detik)
@export var dash_multiplier = 2.5   # kecepatan melesat dibanding kecepatan awal
const WARN_COLOR = Color(1.0, 0.35, 0.35)

var _state = State.ENTER
var _timer = 0.0
var _speed = 0.0
var _player: Node2D


func _ready():
	super()
	_speed = linear_velocity.length()
	_player = get_tree().get_first_node_in_group(&"player")


func _physics_process(delta):
	match _state:
		State.ENTER:
			_timer += delta
			# Sudah cukup masuk ke layar (atau terlalu lama, misalnya muncul di sudut): berhenti.
			var inner = get_viewport_rect().grow(-enter_depth)
			if inner.has_point(global_position) or _timer > 3.0:
				_start_warning()
		State.WARN:
			_timer -= delta
			if _player and _player.visible:
				face_direction(_player.global_position - global_position)  # membidik pemain
			# Berkedip merah 5 kali per detik.
			$AnimatedSprite2D.modulate = WARN_COLOR if fmod(_timer, 0.2) > 0.1 else Color.WHITE
			if _timer <= 0:
				_dash()
		State.DASH:
			pass  # melesat lurus sampai keluar layar


func _start_warning():
	_state = State.WARN
	_timer = warn_time
	linear_velocity = Vector2.ZERO


func _dash():
	_state = State.DASH
	$AnimatedSprite2D.modulate = Color.WHITE
	var direction = Vector2.RIGHT.rotated($AnimatedSprite2D.rotation)  # arah bidikan terakhir
	if _player and _player.visible:
		direction = (_player.global_position - global_position).normalized()
	linear_velocity = direction * _speed * dash_multiplier
	face_direction(linear_velocity)
