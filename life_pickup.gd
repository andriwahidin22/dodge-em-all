extends Area2D
# Item nyawa (fitur 3): muncul di posisi acak, bertahan beberapa detik, lalu hilang.
# Diambil oleh Player lewat signal area_entered (lihat player.gd).

@export var lifetime = 6.0    # lama item bertahan di layar (detik)
@export var blink_time = 2.0  # mulai berkedip di detik-detik terakhir

var _age = 0.0


func _process(delta):
	_age += delta
	var time_left = lifetime - _age
	if time_left <= 0:
		queue_free()
		return
	# Berkedip sebagai tanda item akan hilang.
	visible = time_left > blink_time or fmod(time_left, 0.25) > 0.125
	# Efek "berdenyut" kecil supaya terlihat sebagai item yang bisa diambil.
	$Sprite2D.scale = Vector2.ONE * 1.6 * (1.0 + 0.08 * sin(_age * 6.0))


func collect():
	queue_free()
