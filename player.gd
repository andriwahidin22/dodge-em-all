extends Area2D

signal hit                   # setiap kali tertabrak musuh (nyawa berkurang 1)
signal lives_changed(lives)  # jumlah nyawa berubah (tertabrak, ambil item, game baru, hidup lagi)
signal died                  # nyawa habis -> Main membuka kuis hidup-lagi atau game over
signal enemy_shot            # peluru pemain mengenai musuh (Main menambah skor)

@export var speed = 400 # How fast the player will move (pixels/sec).
var screen_size # Size of the game window.

# Nyawa dan masa kebal (fitur 3).
@export var max_lives = 3
@export var invincible_duration = 1.5  # lama kebal setelah tertabrak (detik)
const REVIVE_INVULNERABLE_TIME = 3.0   # lama kebal setelah hidup lagi dari kuis (detik)
const HURT_FACE_TIME = 0.4             # lama wajah "kesakitan" (animasi hit) setelah tertabrak
var lives = 3
var invincible_time = 0.0              # sisa masa kebal; > 0 berarti sedang kebal
var _hurt_time = 0.0                   # sisa waktu animasi hit

# Menembak (fitur 7): ketuk dua kali (double tap) di layar untuk menembak ke arah titik ketukan.
# Hanya bisa saat karakter diam; selama bergerak, double tap diabaikan.
# Di laptop, double click mouse juga bisa (emulasi sentuh dari mouse aktif).
@export var bullet_scene: PackedScene
@export var fire_cooldown = 0.3          # jeda minimum antar tembakan (detik)
const DOUBLE_TAP_TIME = 300              # jarak waktu maksimum antar ketukan (milidetik)
const DOUBLE_TAP_DISTANCE = 60.0         # jarak maksimum antar titik ketukan (piksel)
const MIN_AIM_DISTANCE = 10.0            # ketukan tepat di atas karakter tidak punya arah
var _fire_cooldown = 0.0
var _is_moving = false                   # karakter bergerak di frame terakhir?
var _last_tap_time = -1000000            # waktu ketukan pertama (milidetik), untuk deteksi double tap
var _last_tap_pos = Vector2.ZERO

# Suara menembak dan musuh kena, dibuat oleh tools/generate_wave_sfx.py.
# Dimuat seperti di wave_audio.gd: kalau file belum ada, game tetap jalan tanpa suara.
const PATH_SHOOT_SFX = "res://art/audio/shoot.wav"
const PATH_ENEMY_HIT_SFX = "res://art/audio/enemy_hit.wav"
const SHOOT_VOLUME_DB = -8.0      # lebih pelan dari SFX wave karena bisa sering diputar
const ENEMY_HIT_VOLUME_DB = -4.0
const SHOOT_PITCH_VARIATION = 0.08  # nada diacak ±8% supaya tembakan beruntun tidak monoton
var _shoot_player: AudioStreamPlayer
var _enemy_hit_player: AudioStreamPlayer

# Kontrol sentuh relatif: karakter ikut bergerak sejauh jari digeser,
# bukan berpindah ke posisi jari. Jadi jari bisa diletakkan di mana saja
# (misalnya di bawah karakter) dan karakter tetap terlihat.
@export var touch_sensitivity = 1.0 # 1.0 = karakter bergerak sejauh jari bergeser.
# Sisa gerakan jari yang belum dijalankan karakter (piksel).
var touch_pending = Vector2.ZERO

func _ready():
	screen_size = get_viewport_rect().size
	_shoot_player = _create_sfx_player(PATH_SHOOT_SFX, SHOOT_VOLUME_DB)
	_enemy_hit_player = _create_sfx_player(PATH_ENEMY_HIT_SFX, ENEMY_HIT_VOLUME_DB)
	hide()


# Pemutar SFX non-posisional. max_polyphony 3: suara baru tidak memotong yang masih berbunyi.
func _create_sfx_player(path: String, volume_db: float) -> AudioStreamPlayer:
	var sfx = AudioStreamPlayer.new()
	if ResourceLoader.exists(path):
		sfx.stream = load(path)
	sfx.volume_db = volume_db
	sfx.max_polyphony = 3
	add_child(sfx)
	return sfx


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
	_is_moving = velocity.length() > 1.0
	if _fire_cooldown > 0:
		_fire_cooldown -= delta


# Ketukan kedua dalam DOUBLE_TAP_TIME dan dekat ketukan pertama = double tap.
# Ketukan ketiga dihitung sebagai ketukan pertama yang baru.
func _handle_tap(event: InputEventScreenTouch):
	var now = Time.get_ticks_msec()
	var is_double = now - _last_tap_time <= DOUBLE_TAP_TIME \
			and event.position.distance_to(_last_tap_pos) <= DOUBLE_TAP_DISTANCE
	if is_double:
		_last_tap_time = -1000000
		# make_input_local: titik ketukan relatif terhadap karakter (sudah memperhitungkan skala layar).
		_try_shoot(make_input_local(event).position)
	else:
		_last_tap_time = now
		_last_tap_pos = event.position


# Menembak ke arah `aim` (relatif terhadap karakter), kalau karakter diam dan jeda tembak sudah lewat.
func _try_shoot(aim: Vector2):
	if _is_moving or _fire_cooldown > 0 or lives <= 0 or bullet_scene == null:
		return
	if aim.length() < MIN_AIM_DISTANCE:
		return
	_fire_cooldown = fire_cooldown
	var bullet = bullet_scene.instantiate()
	bullet.position = position
	bullet.direction = aim.normalized()
	bullet.mob_hit.connect(_on_bullet_hit)
	get_parent().add_child(bullet)
	_play_sfx(_shoot_player, randf_range(1.0 - SHOOT_PITCH_VARIATION, 1.0 + SHOOT_PITCH_VARIATION))


func _on_bullet_hit():
	_play_sfx(_enemy_hit_player, randf_range(0.95, 1.05))
	enemy_shot.emit()


func _play_sfx(sfx: AudioStreamPlayer, pitch: float):
	if sfx.stream == null:
		return
	sfx.pitch_scale = pitch
	sfx.play()


func _update_animation(velocity):
	# Sprite alien hanya punya tampak samping (walk, menghadap kanan), tampak belakang (up),
	# dan tampak depan (idle). Karakter TIDAK diputar seperti di demo asli,
	# supaya alien tidak terbalik saat bergerak ke bawah.
	var sprite = $AnimatedSprite2D
	if _hurt_time > 0:
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
	# Ketukan (jari pertama ditekan) dipakai untuk mendeteksi double tap = menembak.
	elif event is InputEventScreenTouch and event.index == 0 and event.pressed and visible:
		_handle_tap(event)


func reset_touch():
	touch_pending = Vector2.ZERO
	_last_tap_time = -1000000  # ketukan sebelum pause tidak ikut membentuk double tap


func _update_invincibility(delta):
	if _hurt_time > 0:
		_hurt_time -= delta
	if invincible_time <= 0:
		return
	invincible_time -= delta
	if invincible_time > 0:
		# Berkedip 5 kali per detik selama kebal.
		$AnimatedSprite2D.modulate.a = 0.35 if fmod(invincible_time, 0.2) < 0.1 else 1.0
	else:
		$AnimatedSprite2D.modulate.a = 1.0


# Masih kebal (setelah tertabrak atau setelah hidup lagi dari kuis)?
func is_invulnerable() -> bool:
	return invincible_time > 0


# `start_lives`: nyawa awal; -1 = penuh. Melanjutkan dari simpanan memakai nyawa yang tersimpan.
func start(pos, start_lives = -1):
	touch_pending = Vector2.ZERO
	lives = max_lives if start_lives < 1 else mini(start_lives, max_lives)
	_fire_cooldown = 0.0
	invincible_time = 0.0
	_hurt_time = 0.0
	$AnimatedSprite2D.modulate.a = 1.0
	lives_changed.emit(lives)
	position = pos
	rotation = 0
	show()
	$CollisionShape2D.disabled = false


# Menghidupkan kembali pemain (kuis hidup-lagi berhasil) di posisi awal
# dengan `revive_lives` nyawa dan kebal lebih lama dari biasanya.
func revive(pos, revive_lives = 1):
	touch_pending = Vector2.ZERO
	lives = clampi(revive_lives, 1, max_lives)
	lives_changed.emit(lives)
	position = pos
	rotation = 0
	show()
	$CollisionShape2D.set_deferred(&"disabled", false)
	invincible_time = REVIVE_INVULNERABLE_TIME
	_hurt_time = 0.0


func _on_body_entered(body):
	# Sedang kebal atau sudah mati: tabrakan diabaikan.
	if invincible_time > 0 or lives <= 0:
		return
	# Musuh yang sudah kena tembak (sedang memudar) tidak berbahaya.
	if body is Mob and body.is_dead:
		return
	lives -= 1
	body.queue_free()  # musuh yang menabrak ikut hilang supaya tidak menabrak dua kali
	hit.emit()
	lives_changed.emit(lives)
	if lives > 0:
		invincible_time = invincible_duration
		_hurt_time = HURT_FACE_TIME
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
