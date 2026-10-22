class_name Mob
extends RigidBody2D
# Kelas dasar semua musuh.
# Setiap jenis musuh dibuat sebagai Inherited Scene dari mob.tscn (di folder enemies/).
# Jenis yang perilakunya khusus memakai script sendiri yang `extends Mob`.
# Arah dan kecepatan diatur oleh main.gd lewat linear_velocity sebelum musuh ditambahkan ke scene.


func _ready():
	face_direction(linear_velocity)
	$AnimatedSprite2D.play()


# Memutar sprite supaya menghadap arah gerak.
# Jenis musuh yang berbelok (misalnya Chaser) cukup memanggil fungsi ini lagi
# setiap kali linear_velocity berubah.
func face_direction(velocity: Vector2):
	if velocity == Vector2.ZERO:
		return
	var sprite = $AnimatedSprite2D
	# Sprite musuh Kenney menghadap ke kiri, jadi dibalik horizontal agar menghadap
	# ke kanan (= sudut 0), lalu diputar sesuai sudut arah gerak.
	sprite.flip_h = true
	sprite.rotation = velocity.angle()
	# Saat bergerak ke kiri, putaran di atas membuat sprite terbalik (kaki di atas),
	# jadi dibalik vertikal supaya tetap tegak.
	sprite.flip_v = velocity.x < 0


func _on_VisibilityNotifier2D_screen_exited():
	queue_free()
