extends Area2D

signal hit                   # setiap kali tertabrak musuh
signal lives_changed(lives)  # jumlah nyawa berubah (tertabrak, ambil item, game baru)
signal died                  # nyawa habis -> game over

@export var speed = 400 # How fast the player will move (pixels/sec).
var screen_size # Size of the game window.

# Kontrol sentuh relatif: karakter ikut bergerak sejauh jari digeser,
# bukan berpindah ke posisi jari. Jadi jari bisa diletakkan di mana saja
# (misalnya di bawah karakter) dan karakter tetap terlihat.
@export var touch_sensitivity = 1.0 # 1.0 = karakter bergerak sejauh jari bergeser.
# Sisa gerakan jari yang belum dijalankan karakter (piksel).
var touch_pending = Vector2.ZERO

# Nyawa dan masa kebal (fitur 3).
@export var max_lives = 3
@export var invincible_duration = 1.5  # lama kebal setelah tertabrak (detik)
const HURT_FACE_TIME = 0.4             # lama wajah "kesakitan" (animasi hit) di awal masa kebal
const REVIVE_INVINCIBLE_TIME = 3.0     # masa kebal setelah hidup lagi (lebih lama dari biasa)
var lives = 3
var invincible_time = 0.0              # sisa masa kebal; > 0 berarti sedang kebal

func _ready():
	screen_size = get_viewport_rect().size
	hide()


func _process(delta):
	_update_invincibility(delta)

	var velocity = Vector2.ZERO # The player's movement vector.
	if Input.is_action_pressed(&"move_right"):
		velocity.x += 1
	if Input.is_action_pressed(&"move_left"):
		velocity.x -= 1
	if Input.is_action_pressed(&"move_down"):
		velocity.y += 1
	if Input.is_action_pressed(&"move_up"):
		velocity.y -= 1

	if velocity.length() > 0:
		velocity = velocity.normalized() * speed
	elif touch_pending.length() > 0.5:
		# Tidak ada input keyboard: jalankan gerakan jari yang tersisa.
		# Dibatasi `speed` per detik supaya geseran cepat tidak membuat karakter "teleport".
		var step = touch_pending.limit_length(speed * delta)
		touch_pending -= step
		velocity = step / delta
	else:
		touch_pending = Vector2.ZERO

	position += velocity * delta
	# Batas layar dibaca ulang setiap frame karena ukuran layar bisa berubah (layar penuh / rotasi / resize window).
	var area = get_viewport_rect()
	position = position.clamp(area.position, area.end)

	_update_animation(velocity)


func _update_animation(velocity):
	# Sprite alien hanya punya tampak samping (walk, menghadap kanan), tampak belakang (up),
	# dan tampak depan (idle). Karakter TIDAK diputar seperti di demo asli,
	# supaya alien tidak terbalik saat bergerak ke bawah.
	var sprite = $AnimatedSprite2D
	if invincible_time > invincible_duration - HURT_FACE_TIME and invincible_time <= invincible_duration:
		# Sesaat setelah tertabrak: tampilkan wajah kesakitan.
		sprite.play(&"hit")
		return

	if velocity == Vector2.ZERO:
		sprite.play(&"idle")
		return

	if velocity.y < 0 and abs(velocity.y) > abs(velocity.x):
		# Dominan naik: tampak belakang, seperti sedang memanjat/menjauh.
		sprite.play(&"up")
		sprite.flip_h = false
	else:
		# Kiri, kanan, turun, dan diagonal: animasi jalan.
		sprite.play(&"walk")
		# Ambang 10 px/detik supaya getaran kecil jari saat menggeser vertikal
		# tidak membuat alien berbalik arah terus-menerus.
		if abs(velocity.x) > 10:
			sprite.flip_h = velocity.x < 0


func _unhandled_input(event):
	# Hanya jari pertama (index 0) yang dipakai untuk bergerak.
	# _unhandled_input dipakai supaya sentuhan pada tombol UI (Start) tidak ikut menggerakkan Player.
	# Menyentuh layar (InputEventScreenTouch) sengaja tidak menggerakkan karakter;
	# hanya pergeseran jari (InputEventScreenDrag) yang dihitung.
	if event is InputEventScreenDrag and event.index == 0 and visible:
		touch_pending += event.relative * touch_sensitivity


func _update_invincibility(delta):
	if invincible_time <= 0:
		return
	invincible_time -= delta
	if invincible_time > 0:
		# Berkedip 5 kali per detik selama kebal.
		modulate.a = 0.35 if fmod(invincible_time, 0.2) < 0.1 else 1.0
	else:
		modulate.a = 1.0


# `start_lives`: nyawa awal; -1 = penuh. Melanjutkan dari simpanan memakai nyawa yang tersimpan.
func start(pos, start_lives = -1):
	touch_pending = Vector2.ZERO
	lives = max_lives if start_lives < 1 else mini(start_lives, max_lives)
	invincible_time = 0.0
	modulate.a = 1.0
	lives_changed.emit(lives)
	position = pos
	rotation = 0
	show()
	$CollisionShape2D.disabled = false


# Hidup lagi setelah menjawab kuis dengan benar (dipanggil Main).
# Player dikembalikan ke posisi awal dengan `new_lives` nyawa dan masa kebal 3 detik.
func revive(pos, new_lives = 1):
	touch_pending = Vector2.ZERO
	lives = clampi(new_lives, 1, max_lives)
	invincible_time = REVIVE_INVINCIBLE_TIME
	modulate.a = 1.0
	position = pos
	lives_changed.emit(lives)
	show()
	$CollisionShape2D.set_deferred(&"disabled", false)


# Menghentikan Player tanpa game over (dipakai saat keluar ke menu dari pause).
func stop():
	hide()
	invincible_time = 0.0
	modulate.a = 1.0
	touch_pending = Vector2.ZERO
	$CollisionShape2D.set_deferred(&"disabled", true)


func _on_body_entered(body):
	# Sedang kebal atau sudah mati: tabrakan diabaikan.
	if invincible_time > 0 or lives <= 0:
		return
	lives -= 1
	body.queue_free()  # musuh yang menabrak ikut hilang supaya tidak menabrak dua kali
	hit.emit()
	lives_changed.emit(lives)
	if lives > 0:
		invincible_time = invincible_duration
	else:
		hide() # Player disappears after being hit.
		died.emit()
		# Must be deferred as we can't change physics properties on a physics callback.
		$CollisionShape2D.set_deferred(&"disabled", true)


# Item nyawa (life_pickup.tscn) adalah Area2D, jadi terdeteksi lewat area_entered.
func _on_area_entered(area):
	if area.is_in_group(&"life_pickup") and lives > 0 and lives < max_lives:
		lives += 1
		lives_changed.emit(lives)
		area.collect()
