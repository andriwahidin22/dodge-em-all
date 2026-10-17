extends Area2D

signal hit

@export var speed = 400 # How fast the player will move (pixels/sec).
var screen_size # Size of the game window.

# Kontrol sentuh relatif: karakter ikut bergerak sejauh jari digeser,
# bukan berpindah ke posisi jari. Jadi jari bisa diletakkan di mana saja
# (misalnya di bawah karakter) dan karakter tetap terlihat.
@export var touch_sensitivity = 1.0 # 1.0 = karakter bergerak sejauh jari bergeser.
# Sisa gerakan jari yang belum dijalankan karakter (piksel).
var touch_pending = Vector2.ZERO

func _ready():
	screen_size = get_viewport_rect().size
	hide()


func _process(delta):
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

	if velocity.length() > 0:
		$AnimatedSprite2D.play()
	else:
		$AnimatedSprite2D.stop()

	position += velocity * delta
	# Batas layar dibaca ulang setiap frame karena ukuran layar bisa berubah (layar penuh / rotasi / resize window).
	var area = get_viewport_rect()
	position = position.clamp(area.position, area.end)

	if velocity.x != 0:
		$AnimatedSprite2D.animation = &"right"
		$AnimatedSprite2D.flip_v = false
		$Trail.rotation = 0
		$AnimatedSprite2D.flip_h = velocity.x < 0
	elif velocity.y != 0:
		$AnimatedSprite2D.animation = &"up"
		rotation = PI if velocity.y > 0 else 0


func _unhandled_input(event):
	# Hanya jari pertama (index 0) yang dipakai untuk bergerak.
	# _unhandled_input dipakai supaya sentuhan pada tombol UI (Start) tidak ikut menggerakkan Player.
	# Menyentuh layar (InputEventScreenTouch) sengaja tidak menggerakkan karakter;
	# hanya pergeseran jari (InputEventScreenDrag) yang dihitung.
	if event is InputEventScreenDrag and event.index == 0 and visible:
		touch_pending += event.relative * touch_sensitivity


func start(pos):
	touch_pending = Vector2.ZERO
	position = pos
	rotation = 0
	show()
	$CollisionShape2D.disabled = false


func _on_body_entered(_body):
	hide() # Player disappears after being hit.
	hit.emit()
	# Must be deferred as we can't change physics properties on a physics callback.
	$CollisionShape2D.set_deferred(&"disabled", true)
