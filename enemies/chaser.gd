extends Mob
# Chaser (kelelawar): lebih lambat, terus berbelok ke arah pemain selama beberapa detik,
# lalu "menyerah" dan terbang lurus sampai keluar layar.

@export var speed_factor = 0.7  # kecepatan dibanding musuh biasa
@export var chase_time = 5.0    # lama mengejar (detik)
@export var turn_rate = 1.5     # seberapa cepat berbelok; makin besar makin tajam

var _speed = 0.0
var _time = 0.0
var _player: Node2D


func _ready():
	linear_velocity *= speed_factor
	super()
	_speed = linear_velocity.length()
	_player = get_tree().get_first_node_in_group(&"player")


func _physics_process(delta):
	_time += delta
	# Selesai mengejar, atau pemain sudah tidak ada: lanjut lurus.
	if _time > chase_time or _player == null or not _player.visible:
		return
	var desired = (_player.global_position - global_position).normalized() * _speed
	# Berbelok sedikit demi sedikit ke arah pemain (bukan langsung), lalu jaga kecepatannya tetap.
	linear_velocity = linear_velocity.lerp(desired, clampf(turn_rate * delta, 0.0, 1.0))
	linear_velocity = linear_velocity.normalized() * _speed
	face_direction(linear_velocity)
