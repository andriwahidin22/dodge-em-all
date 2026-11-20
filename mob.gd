class_name Mob
extends RigidBody2D
# Kelas dasar semua musuh.
# Setiap jenis musuh dibuat sebagai Inherited Scene dari mob.tscn (di folder enemies/).
# Jenis yang perilakunya khusus memakai script sendiri yang `extends Mob`.
# Arah dan kecepatan diatur oleh main.gd lewat linear_velocity sebelum musuh ditambahkan ke scene.

# Efek kena tembak (fitur 7). Musuh yang punya animasi "hit" (Walker, Chaser, slime kecil)
# menampilkan sprite *_hit; yang tidak punya (Swimmer, Dasher) diwarnai merah.
const HIT_COLOR = Color(1.0, 0.35, 0.35)
const HIT_HOLD_TIME = 0.1   # lama efek kena tembak sebelum mulai memudar (detik)
const FADE_TIME = 0.25      # lama memudar sampai hilang (detik)

var is_dead = false  # sudah kena tembak dan sedang memudar; tidak lagi berbahaya


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


# Dipanggil peluru pemain. Jenis musuh dengan reaksi khusus (Splitter) menimpa fungsi ini.
func take_hit():
	if is_dead:
		return
	_die()


# Musuh berhenti, tidak lagi menabrak atau dihitung sebagai musuh, menampilkan efek
# kena tembak, lalu memudar dan dihapus.
func _die():
	is_dead = true
	remove_from_group(&"mobs")  # tidak dibidik lagi dan tidak dihitung di batas musuh layar
	set_physics_process(false)  # hentikan perilaku khusus (mengejar, melesat, pecah)
	linear_velocity = Vector2.ZERO
	# Ditunda karena bisa dipanggil dari callback fisika (body_entered peluru).
	$CollisionShape2D.set_deferred(&"disabled", true)

	var sprite = $AnimatedSprite2D
	if sprite.sprite_frames.has_animation(&"hit"):
		sprite.play(&"hit")
	else:
		sprite.modulate = HIT_COLOR
	var tween = create_tween()
	tween.tween_property(sprite, ^"modulate:a", 0.0, FADE_TIME).set_delay(HIT_HOLD_TIME)
	tween.tween_callback(queue_free)


func _on_VisibilityNotifier2D_screen_exited():
	queue_free()
